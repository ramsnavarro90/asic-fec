
module encoder # (
    parameter int WIDTH = 4,
    parameter int DEPTH = 4
 )(
  input  logic                          clk,
  input  logic                          rst_n,
  input  logic [WIDTH-1:0][DEPTH-1:0]   data_in,
  output logic [DEPTH-1:0] 	            row_parity,
  output logic [WIDTH-1:0]              col_parity,
  input  logic                          start,
  output logic                          done
);
  
  logic [DEPTH-1:0] row_parity_i;
  logic [WIDTH-1:0] col_parity_i;
  
  // Register parity bits for signal propagation
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      row_parity <= 'b0;
      col_parity <= 'b0;
      done       <= 'b0;
    end
    else if(start) begin
      row_parity <= row_parity_i;
      col_parity <= col_parity_i;
      done       <= 'b1;
    end
    else begin
      row_parity <= row_parity;
      col_parity <= col_parity;
      done       <= 'b0;
    end
  end
  
  // Parity calc for rows
    always_comb begin
        for (int i = 0; i < DEPTH; i++) begin
          row_parity_i[i] = ^data_in[i]; // XOR per fila
        end
    end

    // Parity calc for columns
    always_comb begin
        for (int j = 0; j < WIDTH; j++) begin
            col_parity_i[j] = 1'b0;
            for (int i = 0; i < DEPTH; i++) begin
                col_parity_i[j] ^= data_in[i][j];
            end
        end
    end
  
endmodule



typedef enum logic [1:0] {
  IDLE,
  GET,
  DECODE,
  SET
} dec_st_t;

module decoder #(
    parameter int WIDTH = 4,
    parameter int DEPTH = 4
)(
  input  logic                          clk,
  input  logic                          rst_n,
  input  logic [WIDTH-1:0][DEPTH-1:0]   data_in,
  input  logic [DEPTH-1:0] 	            row_parity,
  input  logic [WIDTH-1:0]              col_parity,
  input  logic                          ready,
  output logic                          complete,
  output logic [WIDTH-1:0][DEPTH-1:0]   data_corrected,
  output logic                          error_detected,
  output logic                          error_corrected
);

  
  // Iteration data
  logic [WIDTH-1:0][DEPTH-1:0]  data_in_i;
  logic [WIDTH-1:0][DEPTH-1:0]  data_corrected_i;
  logic error_detected_i, error_detected_r, error_detected_r2;
  logic error_corrected_i, error_corrected_r, error_corrected_r2;
  logic complete_i;
  
  // FEC Instance
  fec #(
    .WIDTH            (WIDTH),
    .DEPTH            (DEPTH)
  ) fec_i (
    .data_in          (data_in_i),
    .row_parity       (row_parity),
    .col_parity       (col_parity),
    .data_corrected   (data_corrected_i),
    .error_detected   (error_detected_i),
    .error_corrected  (error_corrected_i)
  );
  
  // FSM Decoder state
  dec_st_t dec_st;
  
  assign complete_i = (row_parity==fec_i.calc_row_parity) && (col_parity==fec_i.calc_col_parity) || (error_detected_i && !error_corrected_i);
  
  // ----------------- Decoder FSM -----------------
  
  // Next state logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      dec_st <= IDLE;
   
    else begin
      case (dec_st)
        IDLE:    dec_st <= (ready) ? GET : IDLE;
        
        GET:     dec_st <= DECODE;

        DECODE:  dec_st <= (complete_i) ? SET : DECODE;
        
        SET:     dec_st <= IDLE;

        default: dec_st <= IDLE;
      endcase
      
    end
          
  end

  // Output logic
  always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Decoder outputs
      complete          <= 'b0;
      data_corrected    <= 'b0;
      error_detected    <= 'b0;
      error_corrected   <= 'b0;
      // FEC instance
      data_in_i         <= 'b0;
      error_detected_r  <= 'b0;
      error_detected_r2 <= 'b0; 
      error_corrected_r <= 'b0;
      error_corrected_r2<= 'b0;
    end else begin
      case(dec_st)
        
        // Wait for decode task
        IDLE: begin
          // Decoder outputs
          complete          <= 'b1;
          data_corrected    <= data_corrected;
          error_detected    <= error_detected;
          error_corrected   <= error_corrected;
          // FEC instance
          data_in_i         <= 'b0;
          error_detected_r  <= 'b0;
          error_detected_r2 <= 'b0; 
          error_corrected_r <= 'b0;
          error_corrected_r2<= 'b0;
        end
        
        // Get data from decoder ports
        GET: begin
          // Decoder outputs
          complete          <= 'b0;
          data_corrected    <= data_corrected;
          error_detected    <= error_detected;
          error_corrected   <= error_corrected;
          // FEC instance
          data_in_i         <= data_in;
          error_detected_r  <= 'b0;
          error_detected_r2 <= 'b0; 
          error_corrected_r <= 'b0;
          error_corrected_r2<= 'b0;
        end
        
        // Decoding state
        DECODE: begin
          // Decoder outputs
          complete          <= 'b0;
          data_corrected    <= data_corrected;
          error_detected    <= error_detected;
          error_corrected   <= error_corrected;
          // FEC instance
          data_in_i         <= data_corrected_i;
          error_detected_r  <= error_detected_i;
          error_detected_r2 <= error_detected_r;
          error_corrected_r <= error_corrected_i;
          error_corrected_r2<= error_corrected_r;
        end
        
        // Decode done, set data to decoder ports
        SET: begin
           // Decoder outputs
            complete         <= complete_i;
          // Handle when error was able / unable to correct
          if(error_detected_i && !error_corrected_i) begin
            data_corrected   <= data_in;
            error_detected   <= error_detected_r;
            error_corrected  <= error_corrected_r;
          end else begin
            data_corrected   <= data_corrected_i;
            error_detected   <= error_detected_r2;
            error_corrected  <= error_corrected_r2;
          end
            
            // FEC instance
            data_in_i         <= data_in_i;
            error_detected_r  <= error_detected_i;
            error_detected_r2 <= error_detected_r;
            error_corrected_r <= error_corrected_i;
            error_corrected_r2<= error_corrected_r;
        end
      endcase

    end
  end

endmodule


module fec  #(
    parameter int WIDTH = 4,
    parameter int DEPTH = 4
    ) (
  input  logic [WIDTH-1:0][DEPTH-1:0] data_in,
  input  logic [DEPTH-1:0]            row_parity,
  input  logic [WIDTH-1:0]            col_parity,
//output logic                        complete,
  output logic [WIDTH-1:0][DEPTH-1:0] data_corrected,
  output logic                        error_detected,
  output logic                        error_corrected
//   output logic [$clog2(DEPTH)-1:0]    error_row,
//   output logic [$clog2(WIDTH)-1:0]    error_col
  );
  
  logic [DEPTH-1:0]                   calc_row_parity;
  logic [WIDTH-1:0]                   calc_col_parity;
  logic                               calc_total_parity;
//logic [WIDTH-1:0][DEPTH-1:0]        data_corrected_r;
  logic [$clog2(DEPTH)-1:0]           error_row;
  logic [$clog2(WIDTH)-1:0]           error_col;
  
  // Copia de entrada
    //assign data_corrected = data_in;

    // Cálculo de paridad por filas
    always_comb begin
        for (int i = 0; i < DEPTH; i++) begin
            calc_row_parity[i] = ^data_in[i]; // XOR de cada fila
        end
    end

    // Cálculo de paridad por columnas
    always_comb begin
        for (int j = 0; j < WIDTH; j++) begin
            calc_col_parity[j] = 1'b0;
            for (int i = 0; i < DEPTH; i++) begin
                calc_col_parity[j] ^= data_in[i][j];
            end
        end
    end

    // Cálculo de bit total de paridad (XOR de todos bits de paridad)
    assign calc_total_parity = ^row_parity ^ ^col_parity;

    // Comparar paridades para encontrar error
    logic row_error_found, col_error_found;
    assign row_error_found = (row_parity != calc_row_parity);
    assign col_error_found = (col_parity != calc_col_parity);
  //assign error_detected  = row_error_found || col_error_found || (total_parity != calc_total_parity);
    assign error_detected  = row_error_found || col_error_found || (calc_total_parity);

    // Detectar coordenadas del bit erróneo
    always_comb begin
        error_row = '0;
        error_col = '0;
        error_corrected = 0;
        data_corrected = data_in;

      if(!calc_total_parity) begin
        if (row_error_found || col_error_found) begin
              // Buscar única fila y columna en las que la paridad difiere
              for (int i = 0; i < DEPTH; i++)
                  if (row_parity[i] != calc_row_parity[i])
                      error_row = i;

              for (int j = 0; j < WIDTH; j++)
                  if (col_parity[j] != calc_col_parity[j])
                      error_col = j;

              // Corregir bit en esa posición
              data_corrected[error_row][error_col] = ~data_in[error_row][error_col];
              error_corrected = 1;
          end
      end else begin
        error_corrected = 0;
      end
    end
  
  //assign complete = error_corrected ? ((row_parity==calc_row_parity) && (col_parity==calc_col_parity)) : 1'b0;

endmodule































// module fec #(
//     parameter int WIDTH = 4,
//     parameter int DEPTH = 4
// )(
//     input  logic [WIDTH-1:0][DEPTH-1:0] data_in,      // Matriz de datos [fila][col]
//     input  logic [DEPTH-1:0] row_parity,              // Paridad de cada fila
//     input  logic [WIDTH-1:0] col_parity,              // Paridad de cada columna
//   //input  logic             total_parity,            // Paridad total (esquina inferior derecha)

//     output logic [WIDTH-1:0][DEPTH-1:0] data_corrected,
//     output logic             error_detected,
//     output logic             error_corrected,
//     output logic [$clog2(DEPTH)-1:0] error_row,
//     output logic [$clog2(WIDTH)-1:0] error_col
// );

//     logic [DEPTH-1:0] calc_row_parity;
//     logic [WIDTH-1:0] calc_col_parity;
//     logic             calc_total_parity;

//     // Copia de entrada
//     //assign data_corrected = data_in;

//     // Cálculo de paridad por filas
//     always_comb begin
//         for (int i = 0; i < DEPTH; i++) begin
//             calc_row_parity[i] = ^data_in[i]; // XOR de cada fila
//         end
//     end

//     // Cálculo de paridad por columnas
//     always_comb begin
//         for (int j = 0; j < WIDTH; j++) begin
//             calc_col_parity[j] = 1'b0;
//             for (int i = 0; i < DEPTH; i++) begin
//                 calc_col_parity[j] ^= data_in[i][j];
//             end
//         end
//     end

//     // Cálculo de bit total de paridad (XOR de todos bits de paridad)
//     assign calc_total_parity = ^row_parity ^ ^col_parity;

//     // Comparar paridades para encontrar error
//     logic row_error_found, col_error_found;
//     assign row_error_found = (row_parity != calc_row_parity);
//     assign col_error_found = (col_parity != calc_col_parity);
//   //assign error_detected  = row_error_found || col_error_found || (total_parity != calc_total_parity);
//     assign error_detected  = row_error_found || col_error_found || (calc_total_parity);

//     // Detectar coordenadas del bit erróneo
//     always_comb begin
//         error_row = '0;
//         error_col = '0;
//         error_corrected = 0;
//         data_corrected = data_in;

//       if(!calc_total_parity) begin
//         if (row_error_found || col_error_found) begin
//               // Buscar única fila y columna en las que la paridad difiere
//               for (int i = 0; i < DEPTH; i++)
//                   if (row_parity[i] != calc_row_parity[i])
//                       error_row = i;

//               for (int j = 0; j < WIDTH; j++)
//                   if (col_parity[j] != calc_col_parity[j])
//                       error_col = j;

//               // Corregir bit en esa posición
//               data_corrected[error_row][error_col] = ~data_in[error_row][error_col];
//               error_corrected = 1;
//           end
//       end else begin
//         error_corrected = 0;
//       end
//     end

// endmodule
