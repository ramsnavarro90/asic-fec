
`ifndef _DEFINES_SVH_
`define _DEFINES_SVH_
  // System
  `define SYS_CLK_PERIOD         20
  `define SYS_CLK_EDGE           (`SYS_CLK_PERIOD/2)
  `define SYS_CLK_FREQ           (1e9/`SYS_CLK_PERIOD)
// SPI (unsused)
//   `define SPI_CLK_DIV            10
//   `define SPI_CDW                8 // SPI The width of the clock divider used to generate the SPI clock.
//   `define SPI_FAW                3 // SPI_Log2 of the FIFO depth.
//   `define SPI_CPOL               0 // SPI Clock Polarity.
//   `define SPI_CPHA               0 // SPI CLock Phase.


package fec_pkg;

  parameter int APB_DATA_WIDTH         = 32;
  parameter int APB_ADDR_WIDTH         = 8;

  parameter int UART_MDW               = 8;
  parameter int UART_FAW               = 4;
  parameter int UART_SC                = 8;
  parameter int UART_GFLEN             = 4;
  parameter int UART_PARITY_TYPE       = 1; // 000: None, 001: odd, 010: even, 100: Sticky 0, 101: Sticky 1

  // CRC-Encoder 0 Params
  parameter int                    CRC0_DATA_WIDTH        = 56; // 56b data + 8b CRC = 64b
  parameter int                    CRC0_WIDTH             = 8;
  parameter logic [CRC0_WIDTH:0]   CRC0_POLY              = 9'b10000111;
  parameter logic [CRC0_WIDTH-1:0] CRC0_SEED              = '0;
  parameter int                    CRC0_XOR_OPS_PER_CYCLE = 8;
  parameter int                    ENC0_DATA_WIDTH        = 8; // 8x8=64bits
  parameter int                    ENC0_DATA_DEPTH        = 8;
  parameter int                    ENC0_PAR_DATA_WIDTH    = 10;
  parameter int                    ENC0_PAR_DATA_DEPTH    = 8;
  
  //CRC-Encoder 1 Params
  parameter int                    CRC1_DATA_WIDTH        = 12; // 12b data + 4b CRC = 16b
  parameter int                    CRC1_WIDTH             = 4;
  parameter logic [CRC1_WIDTH:0]   CRC1_POLY              = 'b10011;
  parameter logic [CRC1_WIDTH-1:0] CRC1_SEED              = '0;
  parameter int                    CRC1_XOR_OPS_PER_CYCLE = 4;
  parameter int                    ENC1_DATA_WIDTH        = 4; // 4x4=16bits
  parameter int                    ENC1_DATA_DEPTH        = 4;
  parameter int                    ENC1_PAR_DATA_WIDTH    = 6;
  parameter int                    ENC1_PAR_DATA_DEPTH    = 4;

  // Serializer
  parameter int                    SERIAL_CLK_DIV         = 8;
  parameter int                    SERIAL_DIV_WIDTH       = 16; // Serializer clock div width
  parameter int                    SERIAL_DATA_WIDTH      = ENC0_PAR_DATA_WIDTH;
  parameter int                    SERIAL_DATA_DEPTH      = ENC0_PAR_DATA_DEPTH;

  parameter int                    DL_PREAMBLE_COUNT      = 4; // Must be power of 2

  // Supported commands by the FEC module
  typedef enum bit [3:0] {
    CMD_REG_READ     ='d0, // Register read
    CMD_REG_WRITE    ='d1, // Register write
    CMD_FEC_TX       ='d2, // Transmit data with DL FEC 
    CMD_FEC_RX       ='d3, // Receive data with UL FEC
    CMD_FEC_RS       ='d4,  // Receive transmission result
    CMD_ERR_RS       ='d15 // Command error response
  } command_t;
  
  typedef enum bit {
    REG_READ  = 'd0,
    REG_WRITE = 'd1
  } register_op;

  typedef enum bit[7:0] {
    DL_SER_CLK_DIV    = 8'h00,
    DL_ERR_INJ_MASK_0 = 8'h04,
    DL_ERR_INJ_MASK_1 = 8'h08,
    DL_ERR_INJ_ENABLE = 8'h0c,
    UART_PR           = 8'h20,
    UART_CTRL         = 8'h24,
    UART_CFG          = 8'h28    
  } reg_addr_t;


  typedef enum int {
    UART_NO_ERR = 0,
    UART_RX_RTO_COMMAND,
    UART_RX_RTO_MSG_LENGHT,
    UART_RX_RTO_MSG_TAG,
    UART_RX_RTO_DATA,
    UART_RX_RTO_DATA_BITS,
    UART_RX_FER
  } uart_error_t;

endpackage

`endif



