`include "defines.svh"
import fec_pkg::*;
`include "deser.sv"
`include "rf_pkt.sv"
`include "training.sv"


module dl_controller #(
  parameter int SERIAL_DIV_WIDTH  = 8
)(
  input  logic clk,
  input  logic rst_n,
  input  logic [UART_MDW-1:0] data_in [2**UART_FAW-2:0],  // 56 bits
  input  logic                enc_used,                   // 0 or 1 encoder selection
  input  logic                dl_start,                   // start trigger
  input  logic [7:0] msg_len,
  input  logic [3:0] msg_tag,
  input  logic [CRC0_WIDTH-1:0] crc0_data,
  input  logic [CRC1_WIDTH-1:0] crc1_data,
  input  logic [ENC0_DATA_DEPTH-1:0] enc0_row_p,
  input  logic [ENC0_DATA_WIDTH-1:0] enc0_col_p,
  input  logic [ENC1_DATA_DEPTH-1:0] enc1_row_p,
  input  logic [ENC1_DATA_WIDTH-1:0] enc1_col_p,
  input  logic [SERIAL_DIV_WIDTH-1:0] ser_clk_div,
  input  logic [31:0] err_inj_mask_0,
  input  logic [31:0] err_inj_mask_1,
  input  logic        err_inj_enable,
  output logic        err_inj_enable_clear,   
  output logic dl_done,
  output logic dl_out,
  output logic dl_en
);
  
  typedef enum logic [2:0] {
    S_IDLE             = 'd0,
    S_TRAINING_START   = 'd1,
    S_TRAINING         = 'd2,
    S_SERIALIZER_START = 'd3,
    S_SERIALIZER       = 'd4
  } dl_state_t;
  
  dl_state_t dl_state, next_dl_state;
  
  logic training_out;
  logic training_start;
  logic training_done;
  logic serial_out;
  logic serial_start;
  logic serial_done;
  logic enc_used_r;
  
  // Auto-clear signal for err inj
  assign err_inj_enable_clear = ~enc_used_r & serial_done;
  
   // Current state
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)
      dl_state <= S_IDLE;
    else
      dl_state <= next_dl_state;
  end
  
  // Next state logic
  always_comb begin
    next_dl_state = dl_state;
    
    case(dl_state)
      
      S_IDLE: begin 
        if(dl_start)
          next_dl_state = S_TRAINING_START;
        else 
          next_dl_state = dl_state;
      end
      
      S_TRAINING_START: begin
        next_dl_state = S_TRAINING;
      end
      
      S_TRAINING: begin
        if(training_done)
          next_dl_state = S_SERIALIZER_START;
        else 
          next_dl_state = dl_state;
      end
      
      S_SERIALIZER_START: begin
        next_dl_state = S_SERIALIZER;
      end
      
      S_SERIALIZER: begin
        if(serial_done)
          next_dl_state = S_IDLE;
        else 
          next_dl_state = dl_state;
      end
      
      
      
    endcase
    
  end
    
   // Output logic
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      training_start  <= 'b0;
      serial_start    <= 'b0;
      enc_used_r      <= 'b0;
    end
    else begin
            
      case(dl_state)
        
        S_IDLE: begin
          training_start  <= 'b0;
          serial_start    <= 'b0;
          if(dl_start)
            enc_used_r    <= enc_used;
        end
        
        S_TRAINING_START: begin
          training_start  <= 'b1;
          serial_start    <= 'b0;
        end
        
        S_TRAINING: begin
          training_start  <= 'b0;
          serial_start    <= 'b0;
        end
        
        S_SERIALIZER_START: begin
          training_start  <= 'b0;
          serial_start    <= 'b1;
        end
        
        S_SERIALIZER: begin
          training_start  <= 'b0;
          serial_start    <= 'b0;
        end
        
      endcase
      
    end
    
  end
  
  
 // Downlink output mux
  always_comb begin :dl_mux
    case(dl_state)
      S_IDLE: begin
        dl_out  = 'b0;
        dl_en   = 'b0;
        dl_done = 'b1;
      end
      S_TRAINING: begin
        dl_out  = training_out;
        dl_en   = 'b1;
        dl_done = 'b0;
      end
      S_SERIALIZER: begin
        dl_out  = serial_out;
        dl_en   = 'b1;
        dl_done = 'b0;
      end
    endcase
  end
  
  
  training_preamble #(
    .PREAMBLE_COUNT  (DL_PREAMBLE_COUNT),
    .DIV_WIDTH       (SERIAL_DIV_WIDTH)
  ) training_u (
    .clk             (clk),
    .rst_n           (rst_n),
    .clk_div         (ser_clk_div),
    .start           (training_start),
    .done            (training_done),
    .training        (training_out)
  );
  
  
  logic [$clog2(ENC0_PAR_DATA_WIDTH):0] serial_width;
  logic [$clog2(ENC0_PAR_DATA_DEPTH):0] serial_depth;
  
  always_comb begin
    if(enc_used_r) begin
      serial_width = (ENC1_PAR_DATA_WIDTH-1);
      serial_depth = (ENC1_PAR_DATA_DEPTH-1);
    end else begin
      serial_width = (ENC0_PAR_DATA_WIDTH-1);
      serial_depth = (ENC0_PAR_DATA_DEPTH-1);
    end
  end
  
  
  // Connect rf_packet_scramble and serializer
  logic [SERIAL_DATA_DEPTH-1:0][SERIAL_DATA_WIDTH-1:0] scrambled_data;
    
  rf_packet_scramble #(
    .DATA_WIDTH       (SERIAL_DATA_WIDTH),
    .DATA_DEPTH       (SERIAL_DATA_DEPTH)
  ) dl_rf_pkt_u (
    .enc_used       (enc_used_r),
    .data_in        (data_in),
    .crc0_data      (crc0_data),
    .crc1_data      (crc1_data),
    .enc0_row_p     (enc0_row_p),
    .enc0_col_p     (enc0_col_p),
    .msg_tag        (msg_tag),
    .msg_len        (msg_len),
    .enc1_row_p     (enc1_row_p),
    .enc1_col_p     (enc1_col_p),
    // Err inject registers
    .err_inj_mask   ({err_inj_mask_1, err_inj_mask_0}),
    .err_inj_enable (err_inj_enable),
    .par_out        (scrambled_data)
  );
  
  serializer #(
    .DATA_WIDTH  (SERIAL_DATA_WIDTH),
    .DATA_DEPTH  (SERIAL_DATA_DEPTH),
    .DIV_WIDTH   (SERIAL_DIV_WIDTH)
  ) dl_ser_u (
    .clk         (clk),
    .rst_n       (rst_n),
    .start       (serial_start),
    .width       (serial_width),
    .depth       (serial_depth),
    .par_in      (scrambled_data),
    .clk_div     (ser_clk_div),
    .serial_out  (serial_out),
    .done        (serial_done)
  );

endmodule
