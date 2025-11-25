
//`timescale        1ns/1ps
`default_nettype  none

`include "defines.svh"
import fec_pkg::*;
`include "fec_fsm.sv"
`include "dl_fec.sv"
`include "uart.sv"
`include "dl_ctrl.sv"
`include "reg_cfg.sv"

module fec_top(
  // System
  input  logic   clk,
  input  logic   rst_n,
  // UART
  input  logic  uart_rx,
  output logic  uart_tx,
  // Ready
  output logic  dl_ready,
  // Downlink
  output logic  dl_out,
  output logic  dl_en,
  // Uplink
  input logic   ul_in,
  input logic   ul_en
  );
  
  // Logic variables
  
  // APB Register Config
  logic                      apb_psel;
  logic                      apb_penable;
  logic                      apb_pwrite;
  logic [APB_ADDR_WIDTH-1:0] apb_paddr;
  logic [APB_DATA_WIDTH-1:0] apb_pwdata;
  logic [APB_DATA_WIDTH-1:0] apb_prdata;
  logic                      apb_pslverr;
  
  // FEC FSM Control
  logic                dl_fec_crc0_start;
  logic                dl_fec_crc1_start;
  logic                dl_fec_enc0_done;
  logic                dl_fec_enc1_done;
  logic                dl_ctrl_start;
  logic                dl_ctrl_done;
  logic [1:0]          dl_ctrl_enc_used;
  logic                uart_tx_flush_fsm;
  logic                uart_rx_flush_fsm;
    
  // UART
  logic                uart_en;
  logic                uart_tx_en;
  logic                uart_rx_en;
  logic                uart_rd; 
  logic                uart_wr;
  logic [UART_MDW-1:0] uart_wdata;
  logic [UART_MDW-1:0] uart_rdata;
  logic [15:0]         uart_prescaler;
  logic [3:0]          uart_data_size;
  logic                uart_stop_bits_count;
  logic [2:0]          uart_parity_type;
  
  //logic [3:0]          uart_txfifotr;
  //logic [3:0]          uart_rxfifotr;
  //logic [UART_MDW-1:0] uart_match_data;
  logic [5:0]          uart_timeout_bits;
  logic                uart_loopback_en;
  logic                uart_glitch_filter_en;
  //logic                uart_tx_flush;
  //logic                uart_rx_flush;
  logic                uart_rx_fifo_reg;

  logic                uart_tx_empty;
  logic                uart_tx_full;
  logic                uart_tx_done;  
  logic [UART_MDW-1:0] uart_tx_array_reg [2**UART_FAW-1:0];
  logic [UART_FAW-1:0] uart_tx_level;
  logic                uart_tx_level_below;
  logic                uart_tx_flush;
  
  logic                uart_rx_empty;
  logic                uart_rx_full;
  logic                uart_rx_done;
  logic [UART_MDW-1:0] uart_rx_array_reg [2**UART_FAW-1:0];
  logic [UART_FAW-1:0] uart_rx_level;
  logic                uart_rx_level_above;
  logic                uart_rx_flush;
  
  logic [1:0]          uart_tx_grant;
  logic [1:0]          uart_tx_req;
  
  logic                uart_break_flag;
  logic                uart_match_flag;
  logic                uart_frame_error_flag;
  logic                uart_parity_error_flag;
  logic                uart_overrun_flag;
  logic                uart_timeout_flag;
  logic [1:0]          uart_fatal_errors;
  
  logic [UART_MDW-1:0]         dl_fec_data_out[2**UART_FAW-1:0];  
//logic [3:0]                  dl_fec_frm_type;
  logic [7:0]                  dl_msg_len;
  logic [3:0]                  dl_fec_msg_tag;  
  logic [ENC0_DATA_DEPTH-1:0]  dl_fec_enc0_row_p;
  logic [ENC0_DATA_WIDTH-1:0]  dl_fec_enc0_col_p;
  logic [ENC1_DATA_DEPTH-1:0]  dl_fec_enc1_row_p;
  logic [ENC1_DATA_WIDTH-1:0]  dl_fec_enc1_col_p;
  logic [CRC0_WIDTH-1:0]       dl_fec_crc0_data;
  logic [CRC1_WIDTH-1:0]       dl_fec_crc1_data;
  logic [SERIAL_DIV_WIDTH-1:0] dl_ctrl_clk_div;
  
  logic                        dl_uart_tx_wr;
  logic [UART_MDW-1:0]         dl_uart_tx_wdata;  
  logic                        dl_uart_tx_grant;
  logic                        dl_uart_tx_req;
  
  assign dl_uart_tx_grant  = {1'b0, uart_tx_grant[0]};
  assign uart_fatal_errors = {uart_frame_error_flag, uart_timeout_flag};
  
  // ====== FEC Control FSM  =======
  fec_fsm u_fec_fsm (
    .clk                    (clk),
    .rst_n                  (rst_n),
    .ready                  (dl_ready),
    
    // UART Control
    //.uart_rx_array_0        (uart_rx_array_reg[0]),
    .uart_rx_array          (uart_rx_array_reg),
    .uart_rx_done           (uart_rx_done),
    .uart_rx_level          (uart_rx_level),
  //.uart_rx_fifo_flush     (uart_rx_flush),
    .uart_rx_fifo_flush     (uart_rx_flush_fsm),
    .uart_rx_fifo_reg       (uart_rx_fifo_reg),
    .uart_tx_level          (uart_tx_level),
    .uart_fatal_errors      (uart_fatal_errors),
    
    // Downlink control
    .dl_uart_tx_wr          (dl_uart_tx_wr),
    .dl_uart_tx_wdata       (dl_uart_tx_wdata),
    .dl_uart_tx_grant       (dl_uart_tx_grant),
    .dl_uart_tx_req         (dl_uart_tx_req),
  //.dl_fec_frm_type        (dl_fec_frm_type),
    .dl_fec_msg_tag         (dl_fec_msg_tag),
    .dl_fec_msg_len         (dl_msg_len),
    
    .dl_fec_crc0_start      (dl_fec_crc0_start),
    .dl_fec_enc0_done       (dl_fec_enc0_done),
    .dl_fec_crc1_start      (dl_fec_crc1_start),
    .dl_fec_enc1_done       (dl_fec_enc1_done),
    .dl_ctrl_enc_used       (dl_ctrl_enc_used),
    .dl_ctrl_start          (dl_ctrl_start),
    .dl_ctrl_ser_en         (dl_en),
    
    // Register Access
    .psel                   (apb_psel),
    .penable                (apb_penable),
    .pwrite                 (apb_pwrite),
    .paddr                  (apb_paddr),
    .pwdata                 (apb_pwdata),
    .prdata                 (apb_prdata),
    .pslverr                (apb_pslverr)
  );
  
  // ======  Register configuration with AMBA APB  ======= 
  logic [15:0] uart_prescaler_reg;
  logic [04:0] uart_ctrl_reg;
  logic [13:0] uart_cfg_reg;
  logic [31:0] dl_err_inj_mask_0;
  logic [31:0] dl_err_inj_mask_1;
  logic dl_err_inj_enable, dl_err_inj_enable_clear;
  reg_cfg #(
    .ADDR_WIDTH             (APB_ADDR_WIDTH),
    .DATA_WIDTH             (APB_DATA_WIDTH)
  ) reg_cfg_u (
    .pclk                   (clk),
    .presetn                (rst_n),
    .psel                   (apb_psel),
    .penable                (apb_penable),
    .pwrite                 (apb_pwrite),
    .paddr                  (apb_paddr),
    .pwdata                 (apb_pwdata),
    .prdata                 (apb_prdata),
    .pslverr                (apb_pslverr),
    .DL_SER_CLK_DIV         (dl_ctrl_clk_div),
    .DL_ERR_INJ_MASK_0      (dl_err_inj_mask_0),
    .DL_ERR_INJ_MASK_1      (dl_err_inj_mask_1),
    .DL_ERR_INJ_ENABLE      (dl_err_inj_enable),
    .DL_ERR_INJ_ENABLE_CLEAR(dl_err_inj_enable_clear),
    .UART_PR                (uart_prescaler_reg),
    .UART_CTRL              (uart_ctrl_reg),
    .UART_CFG               (uart_cfg_reg)
  );
  
  // ===========   UART   ===========
  assign uart_prescaler         = uart_prescaler_reg[15:0];
  assign uart_glitch_filter_en  = uart_ctrl_reg[4];
  assign uart_loopback_en       = uart_ctrl_reg[3];
  assign uart_rx_en             = uart_ctrl_reg[2];
  assign uart_tx_en             = uart_ctrl_reg[1];
  assign uart_en                = uart_ctrl_reg[0];
  assign uart_timeout_bits      = uart_cfg_reg[13:8];
  assign uart_parity_type       = uart_cfg_reg[7:5];
  assign uart_stop_bits_count   = uart_cfg_reg[4];
  assign uart_data_size         = uart_cfg_reg[3:0]; 
  //assign uart_match_data        = uart_match_data_reg[UART_MDW-1:0];
  //assign uart_rxfifotr          = uart_rx_fifo_tr_reg[3:0];
  //assign uart_rx_flush          = uart_rx_flush_reg[0] | uart_rx_flush_fsm;
  assign uart_rx_flush          = uart_rx_flush_fsm;
  //assign uart_txfifotr          = uart_tx_fifo_tr_reg[3:0];
  //assign uart_tx_flush          = uart_tx_flush_reg[0] | uart_tx_flush_fsm;
  assign uart_tx_flush          = uart_tx_flush_fsm;
  assign uart_rd                = 1'b0;
  assign uart_wr                = 1'b0;
  
  assign uart_tx_req            = {1'b0, dl_uart_tx_req};
  
  EF_UART #(
    .MDW              (UART_MDW), 
    .FAW              (UART_FAW),
    .SC               (UART_SC),
    .GFLEN            (UART_GFLEN)
    ) uart_u (
    .clk              (clk),
    .rst_n            (rst_n),
    .prescaler        (uart_prescaler),
    .en               (uart_en),
    .tx_en            (uart_tx_en),
    .rx_en            (uart_rx_en),
    .rd               (uart_rd),
    
    .wr0              (dl_uart_tx_wr), // FEC Control FSM
    .wdata0           (dl_uart_tx_wdata),
    .wr1              (1'b0),           // UL FEC Engine TBD
    .wdata1           (7'b0),
    .req              (uart_tx_req),
    .grant            (uart_tx_grant),
    
    .rdata            (uart_rdata),
    .data_size        (uart_data_size),
    .stop_bits_count  (uart_stop_bits_count),
    .parity_type      (uart_parity_type),
    .txfifotr         (4'h0),
    .rxfifotr         (4'h0),
    .match_data       (8'h0),
    .timeout_bits     (uart_timeout_bits),
    .loopback_en      (uart_loopback_en),
    .glitch_filter_en (uart_glitch_filter_en),
    
    .tx_empty         (uart_tx_empty),
    .tx_full          (uart_tx_full),
    .tx_level         (uart_tx_level),
    .tx_level_below   (uart_tx_level_below),
    .tx_done          (uart_tx_done),
    .tx_array_reg     (uart_tx_array_reg),
    .tx_fifo_flush    (uart_tx_flush),
      
    .rx_empty         (uart_rx_empty),
    .rx_full          (uart_rx_full),
    .rx_level         (uart_rx_level),
    .rx_level_above   (uart_rx_level_above),
    .rx_done          (uart_rx_done),
    .rx_array_reg     (uart_rx_array_reg),
    .rx_fifo_flush    (uart_rx_flush),
      
    .break_flag       (uart_break_flag),
    .match_flag       (uart_match_flag),
    .frame_error_flag (uart_frame_error_flag),
    .parity_error_flag(uart_parity_error_flag),
    .overrun_flag     (uart_overrun_flag),
    .timeout_flag     (uart_timeout_flag),
    .rx               (uart_rx),
    .tx               (uart_tx)
  );
  
  
  logic [UART_MDW-1:0] uart_rx_array_r [2**UART_FAW-1:0];
  
  always_ff @(posedge clk or negedge rst_n) begin
    if(~rst_n)
      for(int i=0; i<2**UART_FAW; i++)
          uart_rx_array_r[i] <= 'h0;
    else
      if(uart_rx_fifo_reg) begin
        uart_rx_array_r <= uart_rx_array_reg;
        $display("[%0t] uart_rx_array_reg registered", $time);
      end
      else
        uart_rx_array_r <= uart_rx_array_r;
  end
  

  // ========= DL FEC Engine =========
  dl_fec_engine u_dl_fec (
    .clk          (clk),
    .rst_n        (rst_n),
  //.data_in      (uart_rx_array_reg[0:2**UART_FAW-2]),
  //.data_in      (uart_rx_array_r[0:2**UART_FAW-2]),
    .data_in      (uart_rx_array_r),
    
  //.frm_type     (dl_fec_frm_type),
    .msg_len      (dl_msg_len),
    .msg_tag      (dl_fec_msg_tag),
    
    .crc0_start   (dl_fec_crc0_start),
    .enc0_done    (dl_fec_enc0_done),
    .crc0_data_out(dl_fec_crc0_data),
    .enc0_row_p   (dl_fec_enc0_row_p),
    .enc0_col_p   (dl_fec_enc0_col_p),
    
    .crc1_start   (dl_fec_crc1_start),
    .enc1_done    (dl_fec_enc1_done),
    .crc1_data_out(dl_fec_crc1_data),
    .enc1_row_p   (dl_fec_enc1_row_p),
    .enc1_col_p   (dl_fec_enc1_col_p)
  );
  
  // ========= Downlink controller =========
  dl_controller #(
    .SERIAL_DIV_WIDTH  (SERIAL_DIV_WIDTH)
  //.SERIAL_DATA_WIDTH (ENC0_DATA_WIDTH), // Enc 0 is the highest width
  //.SERIAL_DATA_DEPTH (ENC0_DATA_DEPTH)  // Enc 0 is the highest depth
  ) dl_ctrl_u (
    .clk                  (clk),
    .rst_n                (rst_n),
    .data_in              (uart_rx_array_r[2**UART_FAW-2:0]),
    .msg_tag              (dl_fec_msg_tag),
    .msg_len              (dl_msg_len),
    .enc_used             (dl_ctrl_enc_used[0]),
    
    .dl_start             (dl_ctrl_start),
    .dl_done              (dl_ctrl_done),
    .dl_out               (dl_out),
    .dl_en                (dl_en),
     
    .crc0_data            (dl_fec_crc0_data),
    .enc0_row_p           (dl_fec_enc0_row_p),
    .enc0_col_p           (dl_fec_enc0_col_p),
     
    .crc1_data            (dl_fec_crc1_data),
    .enc1_row_p           (dl_fec_enc1_row_p),
    .enc1_col_p           (dl_fec_enc1_col_p),
    
    .ser_clk_div          (dl_ctrl_clk_div),
    .err_inj_mask_0       (dl_err_inj_mask_0),
    .err_inj_mask_1       (dl_err_inj_mask_1),
    .err_inj_enable       (dl_err_inj_enable),
    .err_inj_enable_clear (dl_err_inj_enable_clear)
   );
    
  
endmodule
















// Defeatured desing with SPI
/*  
 `timescale        1ns/1ps
`default_nettype  none

`include "ef_utils.v"
`include "dl_fec.sv"
`include "fec_fsm.sv"
`include "spi.sv"

module fec_top(
  // System
  input logic   clk,
  input logic   rst_n,
  // SPI
  input  logic  spi_miso,
  output logic  spi_mosi,
  output logic  spi_csb,
  input  logic  spi_ss,
  output logic  spi_sclk,
  // Downlink
  output logic  dl_out,
  output logic  dl_en,
  // Uplink
  input logic   ul_in,
  input logic   ul_en
  );

  // =========== Parameters ============
  localparam int SPI_CDW         = `SPI_CDW; // SPI The width of the clock divider used to generate the SPI clock.
  localparam int SPI_FAW         = `SPI_FAW; // SPI_Log2 of the FIFO depth.
  localparam bit SPI_CPOL        = `SPI_CPOL; // SPI Clock Polarity.
  localparam bit SPI_CPHA        = `SPI_CPHA; // SPI CLock Phase.
  localparam int ENC0_DATA_WIDTH = `ENC0_DATA_WIDTH;
  localparam int ENC0_DATA_DEPTH = `ENC0_DATA_DEPTH;
  localparam int ENC1_DATA_WIDTH = `ENC1_DATA_WIDTH;
  localparam int ENC1_DATA_DEPTH = `ENC1_DATA_DEPTH;
   // ======= Logic declarations =======
  logic [SPI_CDW-1:0]   spi_clk_div = 10; // The SPI clock divider; SPI clock frequency = System Clock Frequency /clk_divider.
  logic              spi_wr = 0; // Write to the TX FIFO.
  logic              spi_rd = 0; // Read from the RX FIFO.
  logic [7:0]        spi_datai;  // Data to place into the TX FIFO.
  logic [7:0]        spi_datao;  // Data from the RX FIFO.
  logic              spi_enable; // enable for spi master pulse generation
  logic              spi_busy;   // spi busy flag.
  logic              spi_done;   // spi done flag.
//logic              spi_mosi;   // Master Out Slave In; this line carries data from the master device to the slave.
//logic              spi_miso;   // Master In Slave Out; this line carries data from the slave device to the master.
//logic              spi_csb;    // Chip Select Bar; this signal selects the slave device to communicate with,typically active low.
//logic              spi_ss = 0; // None
//logic              spi_sclk;   // Serial Clock; this provides the clock signal that synchronizes data transferbetween master and slave devices.
    
  logic                 spi_rx_en = 1;    // Enable the RX FIFO.
  logic                 spi_rx_flush; // Flush the RX FIFO.
  logic [SPI_FAW-1:0]   spi_rx_threshold; // RX FIFO level threshold.
  logic [SPI_FAW-1:0]   spi_rx_level;     // RX FIFO data level.
  logic [SPI_CDW-1:0]   spi_rx_array_reg [2**SPI_FAW-1:0];
    
  logic                 spi_tx_flush = 0; // Flush the TX FIFO.
  logic [SPI_FAW-1:0]   spi_tx_threshold; // TX FIFO level threshold.
  logic [SPI_FAW-1:0]   spi_tx_level;     // TX FIFO data level.
  logic [SPI_CDW-1:0]   spi_tx_array_reg [2**SPI_FAW-1:0];
  
  logic dl_fec_crc0_start;
  logic dl_fec_crc1_start;
  logic dl_fec_enc0_done;
  logic dl_fec_enc1_done;
  
  // ====== FEC Control Control =======
  fec_fsm u_fec_fsm (
    .clk               (clk),
    .rst_n             (rst_n),
    .spi_frm_type      (spi_rx_array_reg[0][3:0]),
    .spi_rx_fifo_flush (spi_rx_flush),
    .dl_fec_crc0_start (dl_fec_crc0_start),
    .dl_fec_enc0_done  (dl_fec_enc0_done),
    .dl_fec_crc1_start (dl_fec_crc1_start),
    .dl_fec_enc1_done  (dl_fec_enc1_done)
  );
  
  // =============== SPI ===============
 
    
  // SPI unit instance
  SPI #(
    .CDW          (SPI_CDW),
    .FAW          (SPI_FAW)
  ) u_spi (
    .clk          (clk),
    .rst_n        (rst_n),
    .CPOL         (SPI_CPOL),
    .CPHA         (SPI_CPHA),
    .clk_divider  (spi_clk_div),
    .wr           (spi_wr),
    .rd           (spi_rd),
    .datai        (spi_datai),
    .datao        (spi_datao),
    .enable       (spi_enable),
    .busy         (spi_busy),
    .done         (spi_done),
    .tx_flush     (spi_tx_flush),
    .tx_array_reg (spi_tx_array_reg),
    .rx_en        (spi_rx_en),
    .rx_flush     (spi_rx_flush),
    .rx_array_reg (spi_rx_array_reg),
    // SPI
    .miso         (spi_miso),
    .mosi         (spi_mosi),
    .csb          (spi_csb),
    .ss           (spi_ss),
    .sclk         (spi_sclk)
  );
  
  logic [7:0]dl_fec_data_out[7:0];
  
  logic [ENC0_DATA_DEPTH-1:0] dl_fec_enc0_row_p;
  logic [ENC0_DATA_WIDTH-1:0] dl_fec_enc0_col_p;
  logic [ENC1_DATA_DEPTH-1:0] dl_fec_enc1_row_p;
  logic [ENC1_DATA_WIDTH-1:0] dl_fec_enc1_col_p;
  
  // DL FEC Engine
  dl_fec_engine u_dl_fec (
    .clk          (clk),
    .rst_n        (rst_n),
    .data_in      (spi_rx_array_reg),
    .data_out     (dl_fec_data_out),
    .crc0_start   (dl_fec_crc0_start),
    .enc0_done    (dl_fec_enc0_done),
    .crc1_start   (dl_fec_crc1_start),
    .enc1_done    (dl_fec_enc1_done),
    .enc0_row_p   (dl_fec_enc0_row_p),
    .enc0_col_p   (dl_fec_enc0_col_p),
    .enc1_row_p   (dl_fec_enc1_row_p),
    .enc1_col_p   (dl_fec_enc1_col_p)
  );
  
  // Downlink controller
//   dl_ctrl u_dl_ctrl (
//   );
  
  
  initial begin
    $display("[%0t] fec_top", $time);
  end
  
endmodule



*/


