
module crc_generator_seq #(
    parameter int DATA_WIDTH = 12,
    parameter int CRC_WIDTH  = 4,
    parameter logic [CRC_WIDTH:0] POLY = 5'b10011,
    parameter logic [CRC_WIDTH-1:0] SEED = '0,
    parameter int XOR_OPS_PER_CYCLE = 1
) (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic [DATA_WIDTH-1:0] data_in,
    output logic [CRC_WIDTH-1:0] crc_out,
    output logic done
);

    typedef enum logic [1:0] {
      S_IDLE,
      S_RUN,
      S_FINISH
    } state_t;
    state_t state, next_state;

    logic [DATA_WIDTH-1:0] shift_reg;
    logic [CRC_WIDTH-1:0] crc;
    logic [$clog2(DATA_WIDTH+1):0] bit_counter;
    logic feedback;

    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            S_IDLE:    if (start) next_state = S_RUN;
            S_RUN:     if (bit_counter == 0) next_state = S_FINISH;
            S_FINISH:  next_state = S_IDLE;
            default:   next_state = S_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            crc <= SEED;
            shift_reg   <=  'b0;
            bit_counter <=  'b0;
            done        <= 1'b0;
            crc_out     <=  'b0;
            feedback    <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (start) begin
                        $display("[%0t][DE-CRC-Gen] Data-in: 0x%0h ", $time, data_in);
                        crc         <= SEED;
                        shift_reg   <= data_in;
                        bit_counter <= DATA_WIDTH;
                        done        <= 1'b0;
                    end
                end

                S_RUN: begin
                  
                    for (int i = 0; i < XOR_OPS_PER_CYCLE; i++) begin
                        if (bit_counter != 'b0) begin
                            feedback <= shift_reg[DATA_WIDTH-1] ^ crc[CRC_WIDTH-1];
                            crc <= crc << 1;
                            if (feedback)
                                crc <= crc ^ POLY[CRC_WIDTH-1:0];
                            shift_reg <= shift_reg << 1;
                            bit_counter <= bit_counter - 1'b1;
                        end
                    end
                end

                S_FINISH: begin
                  $display("[%0t][DE-CRC-Gen] CRC-out: 0x%0h ", $time, crc);
                   crc_out <= crc;
                   done    <= 1'b1;
                end
            endcase
        end
    end

endmodule



module crc_verify_seq #(
    parameter int DATA_WIDTH = 12,
    parameter int CRC_WIDTH  = 4,
    parameter logic [CRC_WIDTH:0] POLY = 5'b10011,
    parameter int XOR_OPS_PER_CYCLE = 1
) (
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic [DATA_WIDTH + CRC_WIDTH - 1:0] data_crc_in,
    output logic crc_valid,
    output logic done
);

    typedef enum logic [1:0] {
      S_IDLE,
      S_RUN,
      S_FINISH
    } state_t;
    state_t state, next_state;

    logic [DATA_WIDTH+CRC_WIDTH-1:0] shift_reg;
    logic [CRC_WIDTH-1:0] crc;
    logic [$clog2(DATA_WIDTH+CRC_WIDTH+1):0] bit_counter;
    logic feedback;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            S_IDLE:   if (start) next_state = S_RUN;
            S_RUN:    if (bit_counter == 0) next_state = S_FINISH;
            S_FINISH: next_state = S_IDLE;
        endcase
    end

  always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            crc         <=  'b0;
            shift_reg   <=  'b0;
            bit_counter <=  'b0;
            crc_valid   <= 1'b0;
            done        <= 1'b0;
            feedback    <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (start) begin
                        shift_reg   <= data_crc_in;
                        crc         <= 'b0;
                        bit_counter <= (DATA_WIDTH+CRC_WIDTH);
                        crc_valid   <= 1'b0;
                        done        <= 1'b0;
                    end
                end

                S_RUN: begin
                    for (int i = 0; i < XOR_OPS_PER_CYCLE; i++) begin
                        if (bit_counter != 'b0) begin
                            feedback <= shift_reg[DATA_WIDTH+CRC_WIDTH-1] ^ crc[CRC_WIDTH-1];
                            crc <= crc << 1;
                            if (feedback)
                                crc <= crc ^ POLY[CRC_WIDTH-1:0];
                            shift_reg   <= shift_reg << 1;
                            bit_counter <= bit_counter - 1'b1;
                        end
                    end
                end

                S_FINISH: begin
                    crc_valid <= (crc == 'b0);
                    done      <= 'b1;
                end
            endcase
        end
    end

endmodule

