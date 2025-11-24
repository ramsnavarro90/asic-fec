
module rf_packet_scramble #(
  parameter int DATA_WIDTH = 10,
  parameter int DATA_DEPTH = 8
)(
  input  logic  enc_used,
  
  // From FEC engine
  // 64-bit encoding signals
  input  logic [UART_MDW-1:0] data_in [2**UART_FAW-2:0], // 56 bits = d0 to d55
  input  logic [CRC0_WIDTH-1:0]      crc0_data,          // d56 to d63
  input  logic [ENC0_DATA_DEPTH-1:0] enc0_row_p,         // r0 to r7
  input  logic [ENC0_DATA_WIDTH-1:0] enc0_col_p,         // c0 to c7
  
  // 16-bit encoding signals
  input  logic [7:0] msg_len,
  input  logic [3:0] msg_tag,
  input  logic [CRC1_WIDTH-1:0]      crc1_data,          // d12 to d15
  input  logic [ENC1_DATA_DEPTH-1:0] enc1_row_p,         // r0 to r3
  input  logic [ENC1_DATA_WIDTH-1:0] enc1_col_p,         // c0 to c3
  
  // Err inject registers
  input logic [63:0] err_inj_mask,
  input logic        err_inj_enable,
    
  // Output to serializer
  output logic [DATA_DEPTH-1:0][DATA_WIDTH-1:0] par_out
);
    
  // Frame format 0 (64-bit frame)
  logic [DATA_DEPTH-1:0][DATA_WIDTH-1:0] format0;
  
  logic  c0,  c1,  c2,  c3,  c4,  c5,  c6,  c7;
  logic  r0,  r1,  r2,  r3,  r4,  r5,  r6,  r7;
  logic  d0,  d1,  d2,  d3,  d4,  d5,  d6,  d7,  d8,  d9;
  logic d10, d11, d12, d13, d14, d15, d16, d17, d18, d19;
  logic d20, d21, d22, d23, d24, d25, d26, d27, d28, d29;
  logic d30, d31, d32, d33, d34, d35, d36, d37, d38, d39;
  logic d40, d41, d42, d43, d44, d45, d46, d47, d48, d49;
  logic d50, d51, d52, d53, d54, d55, d56, d57, d58, d59;
  logic d60, d61, d62, d63;
  logic [63:0] mask;
  logic en;
  
  assign mask = err_inj_mask;
  assign en   = err_inj_enable;
  
  // Compare using xor between mask and en signals  vs  ternary operator (2:1 mux)
  // assign d0  = (mask[0]  & en) ^ data_in[0][0]; - winner
  //assign d0  = (mask[0]  & en) ? ~data_in[0][0]:data_in[0][0]; 
  
  assign d0  = (mask[0]  & en) ^ data_in[0][0];
  assign d1  = (mask[1]  & en) ^ data_in[0][1];
  assign d2  = (mask[2]  & en) ^ data_in[0][2];
  assign d3  = (mask[3]  & en) ^ data_in[0][3];
  assign d4  = (mask[4]  & en) ^ data_in[0][4];
  assign d5  = (mask[5]  & en) ^ data_in[0][5];
  assign d6  = (mask[6]  & en) ^ data_in[0][6];
  assign d7  = (mask[7]  & en) ^ data_in[0][7];

  // Bits d8 a d15 (data_in[1][7:0])
  assign d8  = (mask[8]  & en) ^ data_in[1][0];
  assign d9  = (mask[9]  & en) ^ data_in[1][1];
  assign d10 = (mask[10] & en) ^ data_in[1][2];
  assign d11 = (mask[11] & en) ^ data_in[1][3];
  assign d12 = (mask[12] & en) ^ data_in[1][4];
  assign d13 = (mask[13] & en) ^ data_in[1][5];
  assign d14 = (mask[14] & en) ^ data_in[1][6];
  assign d15 = (mask[15] & en) ^ data_in[1][7];

  // Bits d16 a d23 (data_in[2][7:0])
  assign d16 = (mask[16] & en) ^ data_in[2][0];
  assign d17 = (mask[17] & en) ^ data_in[2][1];
  assign d18 = (mask[18] & en) ^ data_in[2][2];
  assign d19 = (mask[19] & en) ^ data_in[2][3];
  assign d20 = (mask[20] & en) ^ data_in[2][4];
  assign d21 = (mask[21] & en) ^ data_in[2][5];
  assign d22 = (mask[22] & en) ^ data_in[2][6];
  assign d23 = (mask[23] & en) ^ data_in[2][7];

  // Bits d24 a d31 (data_in[3][7:0])
  assign d24 = (mask[24] & en) ^ data_in[3][0];
  assign d25 = (mask[25] & en) ^ data_in[3][1];
  assign d26 = (mask[26] & en) ^ data_in[3][2];
  assign d27 = (mask[27] & en) ^ data_in[3][3];
  assign d28 = (mask[28] & en) ^ data_in[3][4];
  assign d29 = (mask[29] & en) ^ data_in[3][5];
  assign d30 = (mask[30] & en) ^ data_in[3][6];
  assign d31 = (mask[31] & en) ^ data_in[3][7];

  // Bits d32 a d39 (data_in[4][7:0])
  assign d32 = (mask[32] & en) ^ data_in[4][0];
  assign d33 = (mask[33] & en) ^ data_in[4][1];
  assign d34 = (mask[34] & en) ^ data_in[4][2];
  assign d35 = (mask[35] & en) ^ data_in[4][3];
  assign d36 = (mask[36] & en) ^ data_in[4][4];
  assign d37 = (mask[37] & en) ^ data_in[4][5];
  assign d38 = (mask[38] & en) ^ data_in[4][6];
  assign d39 = (mask[39] & en) ^ data_in[4][7];

  // Bits d40 a d47 (data_in[5][7:0])
  assign d40 = (mask[40] & en) ^ data_in[5][0];
  assign d41 = (mask[41] & en) ^ data_in[5][1];
  assign d42 = (mask[42] & en) ^ data_in[5][2];
  assign d43 = (mask[43] & en) ^ data_in[5][3];
  assign d44 = (mask[44] & en) ^ data_in[5][4];
  assign d45 = (mask[45] & en) ^ data_in[5][5];
  assign d46 = (mask[46] & en) ^ data_in[5][6];
  assign d47 = (mask[47] & en) ^ data_in[5][7];

  // Bits d48 a d55 (data_in[6][7:0])
  assign d48 = (mask[48] & en) ^ data_in[6][0];
  assign d49 = (mask[49] & en) ^ data_in[6][1];
  assign d50 = (mask[50] & en) ^ data_in[6][2];
  assign d51 = (mask[51] & en) ^ data_in[6][3];
  assign d52 = (mask[52] & en) ^ data_in[6][4];
  assign d53 = (mask[53] & en) ^ data_in[6][5];
  assign d54 = (mask[54] & en) ^ data_in[6][6];
  assign d55 = (mask[55] & en) ^ data_in[6][7];

  // Bits d56 a d63 (crc0_data[7:0] - CRC)
  assign d56 = (mask[56] & en) ^ crc0_data[0];
  assign d57 = (mask[57] & en) ^ crc0_data[1];
  assign d58 = (mask[58] & en) ^ crc0_data[2];
  assign d59 = (mask[59] & en) ^ crc0_data[3];
  assign d60 = (mask[60] & en) ^ crc0_data[4];
  assign d61 = (mask[61] & en) ^ crc0_data[5];
  assign d62 = (mask[62] & en) ^ crc0_data[6];
  assign d63 = (mask[63] & en) ^ crc0_data[7];
  
  // Parity bits (c0-c7 y r0-r7) ---
  assign c0 = enc0_col_p[0];
  assign c1 = enc0_col_p[1];
  assign c2 = enc0_col_p[2];
  assign c3 = enc0_col_p[3];
  assign c4 = enc0_col_p[4];
  assign c5 = enc0_col_p[5];
  assign c6 = enc0_col_p[6];
  assign c7 = enc0_col_p[7];
  assign r0 = enc0_row_p[0];
  assign r1 = enc0_row_p[1];
  assign r2 = enc0_row_p[2];
  assign r3 = enc0_row_p[3];
  assign r4 = enc0_row_p[4];
  assign r5 = enc0_row_p[5];
  assign r6 = enc0_row_p[6];
  assign r7 = enc0_row_p[7];
  
  assign format0 = '{
    // Bit Index:  9   8   7   6   5   4   3   2   1   0
    // Signal:    c7  d63 d55 d54 d53 r7  d52 d51 d50 d49
    /* 7 */ {c7, d63, d55, d54, d53, r7, d52, d51, d50, d49}, 
    
    // Signal:    c6  d62 d48 d47 d46 r6  d45 d44 d43 d42
    /* 6 */ {c6, d62, d48, d47, d46, r6, d45, d44, d43, d42},
    
    // Signal:    c5  d61 d41 d40 d39 r5  d38 d37 d36 d35
    /* 5 */ {c5, d61, d41, d40, d39, r5, d38, d37, d36, d35},
    
    // Signal:    c4  d60 d34 d33 d32 r4  d31 d30 d29 d28
    /* 4 */ {c4, d60, d34, d33, d32, r4, d31, d30, d29, d28},
    
    // Signal:    c3  d59 d27 d26 d25 r3  d24 d23 d22 d21
    /* 3 */ {c3, d59, d27, d26, d25, r3, d24, d23, d22, d21},
    
    // Signal:    c2  d58 d20 d19 d18 r2  d17 d16 d15 d14
    /* 2 */ {c2, d58, d20, d19, d18, r2, d17, d16, d15, d14},
    
    // Signal:    c1  d57 d13 d12 d11 r1  d10 d9  d8  d7
    /* 1 */ {c1, d57, d13, d12, d11, r1, d10, d9,  d8,  d7},
    
    // Signal:    c0  d56 d6  d5  d4  r0  d3  d2  d1  d0
    /* 0 */ {c0, d56, d6,  d5,  d4,  r0, d3,  d2,  d1,  d0}
  };
  
//   assign format0 = '{
//     //       c7             d63            d55            d54            d53            r7             d52            d51            d50            d49
//     /* 7 */ {enc0_col_p[7], crc0_data[7], data_in[6][7], data_in[6][6], data_in[6][5], enc0_row_p[7], data_in[6][4], data_in[6][3], data_in[6][2], data_in[6][1]}, 
    
//     //       c6             d62            d48            d47            d46            r6             d45            d44            d43            d42
//     /* 6 */ {enc0_col_p[6], crc0_data[6], data_in[6][0], data_in[5][7], data_in[5][6], enc0_row_p[6], data_in[5][5], data_in[5][4], data_in[5][3], data_in[5][2]},
    
//     //       c5             d61            d41            d40            d39            r5             d38            d37            d36            d35
//     /* 5 */ {enc0_col_p[5], crc0_data[5], data_in[5][1], data_in[5][0], data_in[4][7], enc0_row_p[5], data_in[4][6], data_in[4][5], data_in[4][4], data_in[4][3]},
    
//     //       c4             d60            d34            d33            d32            r4             d31            d30            d29            d28
//     /* 4 */ {enc0_col_p[4], crc0_data[4], data_in[4][2], data_in[4][1], data_in[4][0], enc0_row_p[4], data_in[3][7], data_in[3][6], data_in[3][5], data_in[3][4]},
    
//     //       c3             d59            d27            d26            d25            r3             d24            d23            d22            d21
//     /* 3 */ {enc0_col_p[3], crc0_data[3], data_in[3][3], data_in[3][2], data_in[3][1], enc0_row_p[3], data_in[3][0], data_in[2][7], data_in[2][6], data_in[2][5]},
    
//     //       c2             d58            d20            d19            d18            r2             d17            d16            d15            d14
//     /* 2 */ {enc0_col_p[2], crc0_data[2], data_in[2][4], data_in[2][3], data_in[2][2], enc0_row_p[2], data_in[2][1], data_in[2][0], data_in[1][7], data_in[1][6]},
    
//     //       c1             d57            d13            d12            d11            r1             d10            d9             d8             d7
//     /* 1 */ {enc0_col_p[1], crc0_data[1], data_in[1][5], data_in[1][4], data_in[1][3], enc0_row_p[1], data_in[1][2], data_in[1][1], data_in[1][0], data_in[0][7]},
    
//     //       c0             d56            d6             d5             d4             r0             d3             d2             d1             d0
//     /* 0 */ {enc0_col_p[0], crc0_data[0], data_in[0][6], data_in[0][5], data_in[0][4], enc0_row_p[0], data_in[0][3], data_in[0][2], data_in[0][1], data_in[0][0]}
//   };

  // Frame format 1 (16-bit frame)  
  logic [DATA_DEPTH-1:0][DATA_WIDTH-1:0] format1;
    
  assign format1 = '{
    /* 7 */ {10'b0000000000}, 
    /* 6 */ {10'b0000000000}, 
    /* 5 */ {10'b0000000000}, 
    /* 4 */ {10'b0000000000},
    // 				c3				d15				d11			r3				d10			d9
    /* 3 */ {4'b0 ,	enc1_col_p[3], 	crc1_data[3] ,	msg_tag[3], enc1_row_p[3], 	msg_tag[2], msg_tag[1]},
    // 				c2				d14				d8			r2				d7			d6
    /* 2 */ {4'b0 ,	enc1_col_p[2], 	crc1_data[2] ,	msg_tag[0], enc1_row_p[2], 	msg_len[3], msg_len[2]},
    //				c1				d13				d5			r1				d4			d3
    /* 1 */ {4'b0 ,	enc1_col_p[1], 	crc1_data[1] ,	msg_len[1], enc1_row_p[1], 	msg_len[0], msg_len[7]},
    //            	c0				d12				d2			r0				d1			d0
    /* 0 */ {4'b0 ,	enc1_col_p[0], 	crc1_data[0] ,	msg_len[6], enc1_row_p[0],	msg_len[5], msg_len[4]}

  };
  

  // Output multiplexer
  assign par_out = (enc_used)? format1 : format0;

endmodule


/*
module rf_packet_unscramble #(
//   parameter int UART_MDW = 8,
//   parameter int UART_FAW = 3,
  parameter int CRC0_WIDTH = 8,
  parameter int CRC1_WIDTH = 4
//   parameter int ENC0_DATA_DEPTH = 8,
//   parameter int ENC0_DATA_WIDTH = 10,
//   parameter int ENC1_DATA_DEPTH = 4,
//   parameter int ENC1_DATA_WIDTH = 6
)(
  input  logic enc_used,

  // Input desde el serializer (formato scramble)
  input  logic [ENC0_DATA_DEPTH-1:0][ENC0_DATA_WIDTH-1:0] par_in,

  // Outputs comunes
  output logic [UART_MDW-1:0] data_out [2**UART_FAW-2:0], // d0 to d55
  output logic [CRC0_WIDTH-1:0] crc0_data,                // d56 to d63
  output logic [CRC1_WIDTH-1:0] crc1_data,                // d12 to d15
  output logic [ENC0_DATA_DEPTH-1:0] enc0_row_p,
  output logic [ENC0_DATA_WIDTH-1:0] enc0_col_p,
  output logic [ENC1_DATA_DEPTH-1:0] enc1_row_p,
  output logic [ENC1_DATA_WIDTH-1:0] enc1_col_p
);

  // Temporal variables to rearrange the input
  logic [55:0] data_tmp;
  logic [7:0]  crc0_tmp;
  logic [3:0]  crc1_tmp;

  // Decoder for Encoder 0 (64-bit frame)
  always_comb begin
    if (enc_used == 1'b0) begin
      data_tmp = {
        par_in[7][9:6], par_in[6][9:6], par_in[5][9:6], par_in[4][9:6],
        par_in[3][9:6], par_in[2][9:6], par_in[1][9:6], par_in[0][9:6],
        par_in[7][4:1], par_in[6][4:1], par_in[5][4:1], par_in[4][4:1],
        par_in[3][4:1], par_in[2][4:1], par_in[1][4:1], par_in[0][4:1]
      };

      // Assign 56 data bits (d0–d55)
      for (int i = 0; i < 56; i++) begin
        data_out[i] = data_tmp[i];
      end

      // Assign CRC0 bits (d56–d63)
      for (int i = 0; i < 8; i++) begin
        crc0_data[i] = par_in[i][5];
      end

      // Assign row parity
      for (int i = 0; i < 8; i++) begin
        enc0_row_p[i] = par_in[i][5];
      end

      // Assign col parity
      for (int i = 0; i < 8; i++) begin
        enc0_col_p[i] = par_in[i][0];
      end
    end
  end

  // Decoder for Encoder 1 (16-bit frame)
  always_comb begin
    if (enc_used == 1'b1) begin
      // d0–d11
      data_out[0]  = par_in[0][5];
      data_out[1]  = par_in[0][4];
      data_out[2]  = par_in[0][2];
      data_out[3]  = par_in[1][5];
      data_out[4]  = par_in[1][4];
      data_out[5]  = par_in[1][2];
      data_out[6]  = par_in[2][5];
      data_out[7]  = par_in[2][4];
      data_out[8]  = par_in[2][2];
      data_out[9]  = par_in[3][5];
      data_out[10] = par_in[3][4];
      data_out[11] = par_in[3][2];

      // d12–d15 → CRC1
      crc1_data[0] = par_in[0][3];
      crc1_data[1] = par_in[1][3];
      crc1_data[2] = par_in[2][3];
      crc1_data[3] = par_in[3][3];

      // row parity
      enc1_row_p[0] = par_in[0][3];
      enc1_row_p[1] = par_in[1][3];
      enc1_row_p[2] = par_in[2][3];
      enc1_row_p[3] = par_in[3][3];

      // column parity
      enc1_col_p[0] = par_in[0][0];
      enc1_col_p[1] = par_in[1][0];
      enc1_col_p[2] = par_in[2][0];
      enc1_col_p[3] = par_in[3][0];
    end
  end

endmodule
*/
