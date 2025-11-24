module training_preamble #(
  parameter int PREAMBLE_COUNT = 8,
  parameter int DIV_WIDTH = 8
)(
  input logic clk,
  input logic rst_n,
  input logic [DIV_WIDTH-1:0] clk_div,
  input logic start,
  output logic done,
  output logic training
);
  typedef enum logic [1:0] {
    S_IDLE     = 'd0,
    S_TRAINING = 'd1
  } state_t;
  state_t state;

  logic [$clog2(PREAMBLE_COUNT):0] bit_count;
  logic [DIV_WIDTH-1:0] clk_cnt;
  
  // -------------------------------
  // Check parameter: PREAMBLE_COUNT must be power of 2
  // -------------------------------
  if((PREAMBLE_COUNT == 0) || ((PREAMBLE_COUNT & (PREAMBLE_COUNT - 1)) != 0)) begin
    $error("trainee_preamble: PREAMBLE_COUNT (%0d) must be a power of 2!", PREAMBLE_COUNT);
  end

  // FSM - sequential state update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= S_IDLE;
    else begin
      case (state)
        S_IDLE:      state <= (start) ? S_TRAINING : S_IDLE;
        S_TRAINING:  state <= (done)  ? S_IDLE : S_TRAINING;
        default:     state <= S_IDLE;
      endcase
    end
  end

  // Serializer logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      training      <= 'b0;
      clk_cnt       <= 'b0;
      done          <= 'b0;
      bit_count     <= 'b0;
    end else begin
      case (state)
        S_IDLE: begin
          if(start)
            training      <= 'b1;
          else
            training      <= 'b0;
          clk_cnt       <= 'b0;
          done          <= 'b0;
          bit_count     <= 'b0;
        end

        S_TRAINING: begin
          training     <= training;

          if (clk_cnt == (clk_div-'b1)) begin
            clk_cnt <= 0;
            training <= ~training;

            if (bit_count == (PREAMBLE_COUNT-1)<<1) begin
              bit_count <= 'b0;
              done      <= 'b1;
            end else begin
              bit_count <= bit_count + 'b1;
            end

          end else begin
            clk_cnt <= clk_cnt + 'b1;
          end
        end
      endcase
    end
  end

endmodule