`include "ef_utils.v"
`timescale			1ns/1ps
`default_nettype		none


module uart_tx_arbiter (
  input  logic                clk,
  input  logic                rst_n,
  input  logic [1:0]          req,
  output logic [1:0]          grant,
  input  logic [UART_FAW-1:0] tx_level,
  input  logic [UART_MDW-1:0] wdata_in0,
  input  logic [UART_MDW-1:0] wdata_in1,
  input  logic                wr_in0,
  input  logic                wr_in1,
  output logic [UART_MDW-1:0] wdata_out,
  output logic                wr_out
  );
  
  typedef enum logic [2:0] {
    S_UNDEF      = 'bx,
    S_IDLE       = 'b0,
    S_CLIENT_GRANTED_0,
    S_CLIENT_GRANTED_1
  } state_arb_t;
  state_arb_t state, next_state;
  
  //logic granted_client;
  //logic grant_active;
    
  // Mux
  always_comb begin
          
    case(grant)
        
      2'b01: begin
        wdata_out = wdata_in0;
        wr_out    = wr_in0;
      end
        
      2'b10: begin
        wdata_out = wdata_in1;
        wr_out    = wr_in1;
      end
    
      default: begin
        wdata_out = 'b0;
        wr_out    = 'b0;
      end
        
    endcase
        
  end
  
  // Current state logic
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)
      state <= S_IDLE;
    else
      state <= next_state;
  end
  
  // Next state logic
  always_comb begin
    next_state = state;
    
    case(state)
      
      S_IDLE: begin 
        casex(req)
          2'b00: next_state = state;
          2'bx1: begin
            if(tx_level=='b0 & grant[1]==1'b0)
              next_state = S_CLIENT_GRANTED_0;
            else
              next_state = state;
          end
          2'b10: begin
            if(tx_level=='b0 & grant[0]==1'b0)
              next_state = S_CLIENT_GRANTED_1;
            else
              next_state = state;
          end
        endcase
      end
      
      S_CLIENT_GRANTED_0: begin
        if(!req[0])
          next_state = S_IDLE;
        else 
          next_state = state;
      end
      
      S_CLIENT_GRANTED_1: begin
        if(!req[1])
          next_state = S_IDLE;
        else 
          next_state = state;
      end
    endcase
    
  end
  
  // Output logic
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      grant            <= 2'b00;
    end
    else begin
      
      case(state)
        S_IDLE: begin
          grant            <= 2'b00;
        end
        
        S_CLIENT_GRANTED_0: begin
          grant            <= 2'b01;
        end
      
        S_CLIENT_GRANTED_1: begin
          grant            <= 2'b10;
        end
        
        default: begin
          grant            <= 2'b00;
        end
        
      endcase
      
    end
  end
  
  
endmodule

/*
	Copyright 2024 Efabless Corp.

	Author: Efabless Corp. (ip_admin@efabless.com)

	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at

	    http://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.

*/

/*
    A Universal Asynchronous Receiver/Transmitter (UART) 
    - Programmable frame format
        - Data: 5-9 bits
        - Parity: None, Odd, Even, or Sticky at 0/1
    - TX and RX FIFOs with programmable thresholds
    - 16-bit prescaler (PR) for programable baud rate generation
    - Baudrate = CLK/((PR+1)*NUM_SAMPLES)
    - RX synchronizer
    - RX Glich Filter
    - Interrupt Sources:
        + TX fifo not full
        + RX fifo not empty
        + RX fifo level exceeded the threshold
        + TX fifo level is below the threshold
        + Framing Error
        + Parity Error
        + Break is observed
        + Timeout: Nothing received for the time of 4 frames!
        + Overrun
        + Receiving a specific frame
*/

module EF_UART #(
    parameter MDW = 9,   // Max data size/width
    parameter FAW = 4,   // FIFO Address width; Depth=2^AW
    parameter SC  = 8,   // Number of samples per bit/baud
    parameter GFLEN = 8  // Length (number of stages) of the glitch filter
  ) (
    input   wire            clk,
    input   wire            rst_n,
    input   wire [15:0]     prescaler,
    input   wire            en,
    input   wire            tx_en,
    input   wire            rx_en,
    input   wire            rd,
    input   wire [MDW-1:0]  wdata0, // FEC Control FSM
    input   wire            wr0,
    input   wire [MDW-1:0]  wdata1, // UL FEC Engine
    input   wire            wr1,
    input   wire [1:0]      req,
    output  wire [1:0]      grant,

    input   wire [3:0]      data_size,          // 5 - 9
    input   wire            stop_bits_count,    // 0: 1, 1: 2
    input   wire [2:0]      parity_type,        // 000: None, 001: odd, 010: even, 100: Sticky 0, 101: Sticky 1
    input   wire [3:0]      txfifotr,
    input   wire [3:0]      rxfifotr,
    input   wire [MDW-1:0]  match_data,
    input   wire [5:0]      timeout_bits,
    input   wire            loopback_en,
    input   wire            glitch_filter_en,
  
    output  wire            tx_empty,
    output  wire            tx_full,
    output  wire [FAW-1:0]  tx_level,
    output  wire            tx_level_below,
    output  wire            tx_done,
    input   wire            tx_fifo_flush,
    output  wire [MDW-1:0]  tx_array_reg [2**FAW-1:0],

    output  wire [MDW-1:0]  rdata,
    output  wire            rx_empty,
    output  wire            rx_full,
    output  wire [FAW-1:0]  rx_level,
    output  wire            rx_level_above,
    output  wire            rx_done,
    input   wire            rx_fifo_flush,
    output  wire [MDW-1:0]  rx_array_reg [2**FAW-1:0],

    output  wire            break_flag,
    output  wire            match_flag,
    output  wire            frame_error_flag,
    output  wire            parity_error_flag,
    output  wire            overrun_flag,
    output  wire            timeout_flag,

    input   wire            rx,
    output  wire            tx
);

//      (* keep *) wire        tx_done;
//      (* keep *) wire        rx_done;

    wire        b_tick;

    wire [MDW-1:0]  tx_data;
    wire [MDW-1:0]  rx_data;
    
    parameter FIFO_DW = MDW;

    wire        rx_synched;
    wire        rx_filtered;
    wire        rx_in;
  
    wire [MDW-1:0]  wdata;
    wire wr;

    ef_util_sync rx_sync (
        .clk(clk),
        .in(rx),
        .out(rx_synched)
    );

    ef_util_glitch_filter #(.N(GFLEN)) rx_glitch_filter (
        .clk(clk),
        .rst_n(rst_n),
        .en(glitch_filter_en),
        .in(rx_synched),
        .out(rx_filtered)
    );

    assign rx_in =  loopback_en         ? tx            : 
                    glitch_filter_en    ? rx_filtered   : 
                    rx_synched;

    BAUDGEN buad_gen (
        .clk(clk),
        .rst_n(rst_n),
        .prescale(prescaler),
        .en(en),
        .baudtick(b_tick)
    );
  
    
  uart_tx_arbiter tx_arb_u (
    .clk       (clk),
    .rst_n     (rst_n),
    .req       (req),
    .grant     (grant),
    .tx_level  (tx_level),
    .wdata_in0 (wdata0),
    .wdata_in1 (wdata1),
    .wr_in0    (wr0),
    .wr_in1    (wr1),
    .wdata_out (wdata),
    .wr_out    (wr)
  );
  
    
  fifo #( .DW(FIFO_DW), .AW(FAW)
    ) fifo_tx (
      .clk(clk),
      .rst_n(rst_n),
      .rd(tx_done),
      .wr(wr),
      .wdata(wdata),
      .empty(tx_empty),
      .full(tx_full),
      .rdata(tx_data),
      .level(tx_level),
      .flush(tx_fifo_flush),
      .array_reg(tx_array_reg)
    );

    UART_TX #(.MDW(MDW), .NUM_SAMPLES(SC)) uart_tx (
        .clk(clk),
        .resetn(rst_n),
        .tx_start(~tx_empty),
        .b_tick(b_tick & tx_en),
        .data_size(data_size),
        .parity_type(parity_type),
        .stop_bits_count(stop_bits_count),
        .d_in(tx_data),
        .tx_done(tx_done),
        .tx(tx)
    );

    fifo #(.DW(FIFO_DW), .AW(FAW)) fifo_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rd(rd),
        .wr(rx_done),
        .wdata(rx_data),
        .empty(rx_empty),
        .full(rx_full),
        .rdata(rdata),
        .level(rx_level),
      .flush(rx_fifo_flush),
      . array_reg(rx_array_reg)
    );

    UART_RX #(.MDW(MDW), .NUM_SAMPLES(SC)) uart_rx (
        .clk(clk),
        .resetn(rst_n),
        .b_tick(b_tick & rx_en),
        .data_size(data_size),
        .parity_type(parity_type),
        .stop_bits_count(stop_bits_count),
        .match_data(match_data),
        .rx(rx_in),
        .break_flag(break_flag),
        .match_flag(match_flag),
        .parity_error(parity_error_flag),
        .frame_error(frame_error_flag),
        .rx_done(rx_done),
        .dout(rx_data)
    );

    reg [5:0]   bits_count;
    reg [4:0]   samples_count;
    always @ (posedge clk, negedge rst_n) begin
        if(!rst_n) begin
            bits_count <= 0;
            samples_count <= 0;
        end
        else if(b_tick)
            if(rx_done) bits_count <= 0;
            else if(samples_count == (SC - 1)) begin
                samples_count <= 0;
                if(timeout_flag)
                    bits_count <= 0;
                else
                    bits_count <= bits_count + 1;
            end else
                samples_count <= samples_count + 1'b1;
    end

    assign tx_level_below = (tx_level < txfifotr) & ~tx_full;
    assign rx_level_above = (rx_level > rxfifotr) | rx_full;
    assign overrun_flag = rx_full & rx_done;
    assign timeout_flag = (bits_count == timeout_bits);

endmodule

/*
	Copyright 2024 Efabless Corp

    Author: Efabless Corp (ip_admin@efabless.com )
	
	Licensed under the Apache License, Version 2.0 (the "License"); 
	you may not use this file except in compliance with the License. 
	You may obtain a copy of the License at:

	http://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software 
	distributed under the License is distributed on an "AS IS" BASIS, 
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
	See the License for the specific language governing permissions and 
	limitations under the License.
*/


/*
    A FIFO
    Depth = 2^AW
    Width = DW
*/
//module ef_util_fifo #(parameter DW=8, AW=4)(
module fifo #(parameter DW=8, AW=4)(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            rd,
    input   wire            wr,
    input   wire            flush,
    input   wire [DW-1:0]   wdata,
    output  wire            empty,
    output  wire            full,
    output  wire [DW-1:0]   rdata,
    output  wire [AW-1:0]   level,
    output  reg  [DW-1:0]   array_reg [2**AW-1:0]
);

    localparam  DEPTH = 2**AW;

    //Internal Signal declarations
    //reg [DW-1:0]  array_reg [DEPTH-1:0];
    reg [AW-1:0]  w_ptr_reg;
    reg [AW-1:0]  w_ptr_next;
    reg [AW-1:0]  w_ptr_succ;
    reg [AW-1:0]  r_ptr_reg;
    reg [AW-1:0]  r_ptr_next;
    reg [AW-1:0]  r_ptr_succ;

    // Level
    reg [AW-1:0] level_reg;
    reg [AW-1:0] level_next;      
    reg full_reg;
    reg empty_reg;
    reg full_next;
    reg empty_next;

    wire w_en;

    always @ (posedge clk, negedge rst_n)
      if(!rst_n) begin
        for(int i=0; i<2**AW; i++)
          array_reg[i] <= 'h0;
      end else if(w_en) begin
            array_reg[w_ptr_reg] <= wdata;
      end else if(flush) begin
        for(int i=0; i<2**AW; i++)
          array_reg[i] <= 'h0;
      end else
        array_reg[w_ptr_reg] <= array_reg[w_ptr_reg];

    assign rdata = array_reg[r_ptr_reg];   
    assign w_en = wr & ~full_reg;           

    //State Machine
    always @ (posedge clk, negedge rst_n) begin 
        if(!rst_n)
            begin
                w_ptr_reg <= 'b0;
                r_ptr_reg <= 'b0;
                full_reg  <= 1'b0;
                empty_reg <= 1'b1;
                level_reg <= 'd0;
                
            end
        else if(flush)
            begin
                w_ptr_reg <= 'b0;
                r_ptr_reg <= 'b0;
                full_reg  <= 1'b0;
                empty_reg <= 1'b1;
                level_reg <= 'd0;
                
            end
        else
            begin
                w_ptr_reg <= w_ptr_next;
                r_ptr_reg <= r_ptr_next;
                full_reg  <= full_next;
                empty_reg <= empty_next;
                level_reg <= level_next;
            end
    end

    //Next State Logic
    always @* begin
        w_ptr_succ  =   w_ptr_reg + 1;
        r_ptr_succ  =   r_ptr_reg + 1;
        w_ptr_next  =   w_ptr_reg;
        r_ptr_next  =   r_ptr_reg;
        full_next   =   full_reg;
        empty_next  =   empty_reg;
        level_next  =   level_reg;

        case({w_en,rd})
            //2'b00: nop
            2'b01: 
                if(~empty_reg) begin
                    r_ptr_next = r_ptr_succ;
                    full_next = 1'b0;
                    level_next = level_reg - 1;
                    if (r_ptr_succ == w_ptr_reg)
                        empty_next = 1'b1;
                end
            
            2'b10: 
                if(~full_reg) begin
                    w_ptr_next = w_ptr_succ;
                    empty_next = 1'b0;
                    level_next = level_reg + 1;
                    if (w_ptr_succ == r_ptr_reg)
                        full_next = 1'b1;
                end
            
            2'b11: begin
                w_ptr_next = w_ptr_succ;
                r_ptr_next = r_ptr_succ;
            end
        endcase
    end

    //Set Full and Empty
    assign full = full_reg;
    assign empty = empty_reg;
    assign level = level_reg;
  
endmodule


module BAUDGEN
(
    input   wire        clk,
    input   wire        rst_n,
    input   wire [15:0] prescale, 
    input   wire        en,
    output  wire        baudtick
);

    reg [15:0]  count_reg;
    wire [15:0] count_next;

    //Counter
    always @ (posedge clk, negedge rst_n) begin
        if(!rst_n)
            count_reg <= 0;
        else if(en)
            count_reg <= count_next;
    end

    assign count_next = ((count_reg == prescale) ? 0 : count_reg + 1'b1);
    assign baudtick = ((count_reg == prescale) ? 1'b1 : 1'b0);

endmodule

/*
    UART Receiver
*/
module UART_RX #(parameter NUM_SAMPLES = 16, MDW = 8)(
    input   wire            clk,
    input   wire            resetn,
    input   wire            b_tick,             // Baud generator tick
    input   wire [3:0]      data_size,          // 5 - 9
    input   wire            stop_bits_count,    // 0: 1, 1: 2
    input   wire [2:0]      parity_type,        // 000: None, 001: odd, 010: even, 
                                                // 100: Sticky 0, 101: Sticky 1
    input   wire            rx,                 // RS-232 data port
    input   wire [MDW-1:0]  match_data,
    output  reg             rx_done,            // Transfer completed
    output  wire            parity_error,       // Parity Error
    output  wire            frame_error,        // Framing Error
    output  wire            break_flag,         // Break flag
    output  wire            match_flag,
    output  wire [MDW-1:0]  dout                // Received data
);
    //STATE DEFINES  
    localparam [2:0] idle_st    = 3'b000;
    localparam [2:0] start_st   = 3'b001;
    localparam [2:0] data_st    = 3'b010;
    localparam [2:0] parity_st  = 3'b011;
    localparam [2:0] stop0_st   = 3'b100;
    localparam [2:0] stop1_st   = 3'b101;

    //Internal Signals  
    reg [2:0]   current_state;
    reg [2:0]   next_state;
    reg [3:0]   b_reg;            //baud-rate/over sampling counter
    reg [3:0]   b_next;
    reg [3:0]   count_reg;        //data-bit counter
    reg [3:0]   count_next;
  reg [MDW-1:0]   data_reg;         //data register
  reg [MDW-1:0]   data_next;
    reg         p_error_reg;
    reg         p_error_next;
    reg         f_error_reg;
    reg         f_error_next;

    //State Machine  
    always @ (posedge clk, negedge resetn) begin
        if(!resetn) begin
            current_state <= idle_st;
            b_reg <= 0;
            count_reg <= 0;
            data_reg <= 0;
            p_error_reg <= 0;
        end else begin
            current_state <= next_state;
            b_reg <= b_next;
            count_reg <= count_next;
            data_reg <= data_next;
            if(current_state == idle_st) 
                p_error_reg <= 0;
            else 
                if(p_error_next) 
                    p_error_reg <= p_error_next;
            if(current_state == idle_st) 
                    f_error_reg <= 0;
                else 
                    if(f_error_next) 
                        f_error_reg <= f_error_next;
        end
    end

    //Next State Logic 
    always @* begin
        next_state = current_state;
        b_next = b_reg;
        count_next = count_reg;
        data_next = data_reg;
        rx_done = 1'b0;
        p_error_next = 1'b0;
        f_error_next = 1'b0;
            
        case(current_state)
            idle_st:
                if(~rx & b_tick)
                begin
                    next_state = start_st;
                    b_next = 0;
                end
                
            start_st:
                if(b_tick)
                    if(b_reg == (NUM_SAMPLES/2 - 1)) begin
                        next_state = data_st;
                        b_next = 0;
                        count_next = 0;
                    end else
                        b_next = b_reg + 1'b1;
                    
            data_st:
                if(b_tick)
                    if(b_reg == (NUM_SAMPLES - 1)) begin
                        b_next = 0;
                      data_next = {rx, data_reg [(MDW-1):1]};
                        if(count_next == (data_size - 1)) 
                            if(parity_type == 3'b000)         
                                next_state = stop0_st;
                            else
                                next_state = parity_st;
                        else
                            count_next = count_reg + 1'b1;
                    end else
                        b_next = b_reg + 1;
            
            parity_st:
                if(b_tick)
                    if(b_reg == (NUM_SAMPLES - 1)) begin
                        b_next = 0;
                        next_state = stop0_st;
                        case (parity_type)
                            3'b001 : //Odd parity
                                if(~^dout != rx) p_error_next = 1;
                            3'b010 : //Even parity
                                if(^dout != rx) p_error_next = 1;
                            3'b100 : //Sticky 0 parity
                                if(1'b0 != rx) p_error_next = 1;
                            3'b101 : //Sticky 1 parity
                                if(1'b1 != rx) p_error_next = 1;
                        endcase
                    end else
                        b_next = b_reg + 1;  
            stop0_st:
                if(b_tick)
                    if(b_reg == (NUM_SAMPLES - 1)) begin 
                        b_next = 0;
                        if(!rx) f_error_next = 1;
                        if(stop_bits_count)         //Two stop bits
                            next_state = stop1_st;
                        else begin                  //One stop bit 
                            next_state = idle_st;
                            rx_done = 1'b1;
                        end
                    end else
                        b_next = b_reg + 1;
            stop1_st:
                if(b_tick)
                    if(b_reg == (NUM_SAMPLES - 1)) begin //Two stop bits
                        b_next = 0;
                        next_state = idle_st;
                        rx_done = 1'b1;
                        if(!rx) f_error_next = 1;
                    end else
                        b_next = b_reg + 1;
        endcase
    end
  
    // Break Detector
    reg [11:0] brk;
    always @ (posedge clk, negedge resetn) begin
        if(!resetn) 
            brk <= 12'hFFF;
        else if(b_tick)
            if(b_reg == (NUM_SAMPLES - 1)) begin
                if(current_state == idle_st)
                    brk <= 12'hFFF;
                else
                    brk <= {brk[10:0], rx};
            end
    end

    assign      dout            =   data_reg /*>> (9-data_size)*/;
    assign      parity_error    =   p_error_reg & rx_done;
    assign      frame_error     =   f_error_next & rx_done;
  //assign      frame_error     =   f_error_reg & rx_done;
    assign      break_flag      =   (brk == 0);
    assign      match_flag      =   (match_data == dout) & rx_done;

endmodule

/*
    UART Transmitter
*/
module UART_TX #(parameter NUM_SAMPLES = 16, MDW = 8)(
    input   wire                clk,
    input   wire                resetn,
    input   wire                tx_start,        
    input   wire                b_tick,             //baud rate tick
    input   wire [3:0]          data_size,          // 5 - 9
    input   wire                stop_bits_count,    // 0: 1, 1: 2
    input   wire [2:0]          parity_type,        // 000: None, 001: odd, 010: even, 
                                                    // 100: Sticky 0, 101: Sticky 1
    input   wire [MDW-1:0]      d_in,               // input data to transmit
    output  reg                 tx_done,            // Transfer finished
    output  wire                tx                  // output data to RS-232
);
  
    //STATE DEFINES  
    localparam [2:0] idle_st    = 3'b000;
    localparam [2:0] start_st   = 3'b001;
    localparam [2:0] data_st    = 3'b010;
    localparam [2:0] parity_st  = 3'b011;
    localparam [2:0] stop0_st   = 3'b100;
    localparam [2:0] stop1_st   = 3'b101;
/*
    //STATE DEFINES  
    localparam [1:0] idle_st = 2'b00;
    localparam [1:0] start_st = 2'b01;
    localparam [1:0] data_st = 2'b11;
    localparam [1:0] stop_st = 2'b10;
*/
    //Internal Signals  
    reg [2:0]   current_state;
    reg [2:0]   next_state;
    reg [3:0]   b_reg;          // baud tick counter
    reg [3:0]   b_next;
    reg [3:0]   count_reg;      // data bit counter
    reg [3:0]   count_next;
    reg [8:0]   data_reg;       // data register
    reg [8:0]   data_next;
    reg         tx_reg;         // output data reg
    reg         tx_next;

    // prepare the data to claculate the parity by removing any extra bits entered
	// by the user by error
    wire [MDW-1:0] pdata = (d_in) & ~({MDW{1'b1}} << data_size);

    //State Machine  
    always @(posedge clk, negedge resetn) begin
        if(!resetn) begin
            current_state   <= idle_st;
            b_reg           <= 0;
            count_reg       <= 0;
            data_reg        <= 0;
            tx_reg          <= 1'b1;
        end else begin
            current_state   <= next_state;
            b_reg           <= b_next;
            count_reg       <= count_next;
            data_reg        <= data_next;
            tx_reg          <= tx_next;
        end
    end

    //Next State Logic  
    always @* begin
        next_state  =   current_state;
        tx_done     =   1'b0;
        b_next      =   b_reg;
        count_next  =   count_reg;
        data_next   =   data_reg;
        tx_next     =   tx_reg;
        
        case(current_state)
            idle_st: begin
                tx_next = 1'b1;
                if(tx_start) begin
                    next_state = start_st;
                    b_next = 0;
                    data_next = d_in;
                end
            end
            
            start_st: begin //send start bit
                tx_next = 1'b0;
                if(b_tick)
                    if(b_reg == (NUM_SAMPLES)) begin
                        next_state = data_st;
                        b_next = 0;
                        count_next = 0;
                    end
                    else
                        b_next = b_reg + 1;
            end
            
            data_st: begin //send data serially
              tx_next = data_reg[0];
              //tx_next = data_reg[MDW-1];
              
                if(b_tick)
                    if(b_reg == (NUM_SAMPLES - 1)) begin
                        b_next = 0;
                        data_next = data_reg >> 1;
                        //data_next = data_reg << 1;
                        if(count_next == (data_size - 1)) 
                            if(parity_type == 3'b000)         
                                next_state = stop0_st;
                            else
                                next_state = parity_st;
                        else
                            count_next = count_reg + 1;
                    end
                    else
                        b_next = b_reg + 1;
            end
            
            parity_st: begin
                tx_next = 1'b0;
                case (parity_type)
                    3'b001 : // Odd parity
                        tx_next = ~^pdata;
                    3'b010 : // Even parity
                        tx_next = ^pdata;
                    3'b100 : // Sticky 0 parity
                        tx_next = 0;
                    3'b101 : // Sticky 1 parity
                        tx_next = 1;
                endcase
                if(b_tick)
                    if(b_reg == (NUM_SAMPLES - 1)) begin
                        b_next = 0;
                        next_state = stop0_st;
                    end else
                        b_next = b_reg + 1;
            end

            stop0_st: begin //send stop bit
                tx_next = 1'b1;
                if(b_tick)
                    if(b_reg == (NUM_SAMPLES - 1)) begin
                        b_next = 0;
                        if(stop_bits_count)         //Two stop bits
                                next_state = stop1_st;
                        else begin                  //One stop bit 
                            next_state = idle_st;
                            tx_done = 1'b1;
                        end        
                    end
                    else
                        b_next = b_reg + 1;
            end

            stop1_st: begin
                tx_next = 1'b1;
                if(b_tick)
                    if(b_reg == (NUM_SAMPLES - 1)) begin //Two stop bits
                        b_next = 0;
                        next_state = idle_st;
                        tx_done = 1'b1;
                    end else
                        b_next = b_reg + 1;
            end
        endcase
    end
  
    assign tx = tx_reg;
  
endmodule


// module uart_tx_arbiter #(
//     parameter int CLIENTS = 2
//   ) (
//   input  logic                clk,
//   input  logic                rst_n,
//   input  logic                req       [CLIENTS-1:0],
//   output logic                grant     [CLIENTS-1:0],
//   input  logic [UART_MDW-1:0] wdata_in  [CLIENTS-1:0],
//   input  logic                wr_in     [CLIENTS-1:0],
//   output logic [UART_MDW-1:0] wdata_out,
//   output logic                wr_out
//   );
  
//   typedef enum logic [CLIENTS:0] {
//     S_IDLE,
//     S_CLIENT_[2]
//   } state_arb_t;
  
//   state_arb_t state, next_state;
  
//   logic [$clog2(CLIENTS)-1:0] dispatch_queue [CLIENTS-1:0] ;
//   logic [$clog2(CLIENTS)-1:0] dispatch_ptr;    // Write pointer for dispatch
//   logic [$clog2(CLIENTS)-1:0] granted_client;
//   logic grant_active;
  
//   assign granted_client = dispatch_queue[0];
//   assign wdata_out      = (grant_active)? wdata_in[granted_client]: 'b0;
//   assign wr_out         = (grant_active)? wr_in   [granted_client]: 'b0;
  
//   // Current state logic
//   always_ff @(posedge clk or negedge rst_n) begin
//     if(!rst_n)
//       state <= S_IDLE;
//     else
//       state <= next_state;
//   end
  
//   // Next state logic
//   always_comb begin
//     next_state = state;
    
//     case(state)
      
//       S_IDLE: begin 
//         if(any_condition)
//           next_state = S_CLIENT_0;
//         else 
//           next_state = state;
//       end
      
//       // Use generate CLIENT_GRANT_N blocks
//       S_CLIENT_0: begin
//         //if(!req[0])
//       end
      
//       S_CLIENT_1: begin
        
//       end
//     endcase
    
//   end
  
//   // Output logic
//   always_ff @(posedge clk or negedge rst_n) begin
//     if(!rst_n) begin
//       foreach(dispatch_queue[ii])
//         dispatch_queue[ii] <= 'b0;
//       dispatch_ptr     <= 'b0;
//       grant_active     <= 'b0;
      
//     end
//     else begin
      
//       case(state)
//         S_IDLE: begin
          
//         end
        
//         S_CLIENT_0: begin
          
//         end
      
//         S_CLIENT_1: begin

//         end
        
//         default: begin
          
//         end
        
//       endcase
      
//     end
//   end
  
  
// endmodule