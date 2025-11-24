// Auto-generated APB Register Module
module reg_cfg #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)(
  // AMBA APB interface
    input  logic                  pclk,
    input  logic                  presetn,
    input  logic                  psel,
    input  logic                  penable,
    input  logic                  pwrite,
    input  logic [ADDR_WIDTH-1:0] paddr,
    input  logic [DATA_WIDTH-1:0] pwdata,
    output logic [DATA_WIDTH-1:0] prdata,
    output logic                  pslverr,
  
    // Regiters
    output logic [15:0] DL_SER_CLK_DIV,
  
    // Err inject registers
    output logic [31:0] DL_ERR_INJ_MASK_0,
    output logic [31:0] DL_ERR_INJ_MASK_1,
    output logic [0:0] DL_ERR_INJ_ENABLE,
    input  logic       DL_ERR_INJ_ENABLE_CLEAR,
    // UART
  output logic [15:0] UART_PR,
  output logic [4:0] UART_CTRL,
  output logic [13:0] UART_CFG
);

    // -------------------------
    // Register Declarations
    // -------------------------
    // DL_SER_CLK_DIV register
    // Serializer clock divisor for downlink transmission.
    // UART_RXDATA register
    // RX Data register; the interface to the ReceiveFIFO.
    // UART_TXDATA register
    // TX Data register; the interface to the ReceiveFIFO.
    // UART_PR register
    // The Prescaler register; used to determine thebaud rate.
    // UART_CTRL register
    // UART Control Register
    // UART_CFG register
    // UART Configuration Register

    // -------------------------
    // Reset & Write Logic
    // -------------------------
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            pslverr           <= 1'b0;
            DL_SER_CLK_DIV    <= 16'h4;
            DL_ERR_INJ_MASK_0 <= 32'h0;
            DL_ERR_INJ_MASK_1 <= 32'h0;
            DL_ERR_INJ_ENABLE <= 1'h0;
            //UART_PR           <= 16'h18;
            UART_PR           <= 16'h00;
            UART_CTRL         <= 5'h7;
            UART_CFG          <= 14'h3F28;
        end
        else begin
          
          // Clear registers logic
          if(DL_ERR_INJ_ENABLE_CLEAR) begin
            //$display("[%0t][DE-REG_CFG] Clearing Err Inj", $time);
            DL_ERR_INJ_ENABLE <= 1'h0;
          end
          
          // APB access logic (Lower priority)
          else if (psel && penable && pwrite) begin
            $display("[%0t][DE-REG_CFG] Register write Addr: 0x%0h, Data: 0x%0h", $time, paddr, pwdata);
                case (paddr)
                  8'h00: DL_SER_CLK_DIV[15:0]    <= pwdata[15:0];
                  8'h04: DL_ERR_INJ_MASK_0[31:0] <= pwdata[31:0];
                  8'h08: DL_ERR_INJ_MASK_1[31:0] <= pwdata[31:0];
                  8'h0c: DL_ERR_INJ_ENABLE[0:0]  <= pwdata[0:0];
                  8'h20: UART_PR[15:0]           <= pwdata[15:0];
                  8'h24: UART_CTRL[4:0]          <= pwdata[4:0];
                  8'h28: UART_CFG[13:0]          <= pwdata[13:0];
                  default: begin
                    pslverr           <= 1'b1;
                    DL_SER_CLK_DIV    <= DL_SER_CLK_DIV;
                    DL_ERR_INJ_MASK_0 <= DL_ERR_INJ_MASK_0;
                    DL_ERR_INJ_MASK_1 <= DL_ERR_INJ_MASK_1;
                    DL_ERR_INJ_ENABLE <= DL_ERR_INJ_ENABLE;
                    UART_PR           <= UART_PR;
                    UART_CTRL         <= UART_CTRL;
                    UART_CFG          <= UART_CFG;
                  end
                  
                endcase
            
            end
          
          else begin
            pslverr           <= 1'b0;
            DL_SER_CLK_DIV    <= DL_SER_CLK_DIV;
            DL_ERR_INJ_MASK_0 <= DL_ERR_INJ_MASK_0;
            DL_ERR_INJ_MASK_1 <= DL_ERR_INJ_MASK_1;
            DL_ERR_INJ_ENABLE <= DL_ERR_INJ_ENABLE;
            UART_PR           <= UART_PR;
            UART_CTRL         <= UART_CTRL;
            UART_CFG          <= UART_CFG;
          end

          
        end
    end
  
  
    // -------------------------
    // Read Logic
    // -------------------------
    always_comb begin
        prdata = 32'h0;
        if (psel && !pwrite) begin
          case (paddr)
            8'h00: prdata = {16'h0, DL_SER_CLK_DIV};
            8'h04: prdata = DL_ERR_INJ_MASK_0;
            8'h08: prdata = DL_ERR_INJ_MASK_1;
            8'h0C: prdata = {31'b0, DL_ERR_INJ_ENABLE};
            8'h20: prdata = {16'h0, UART_PR};
            8'h24: prdata = {27'h0, UART_CTRL};
            8'h28: prdata = {18'h0, UART_CFG};
            default: prdata = 32'hCAFE_CAFE;
          endcase
          $display("[%0t][DE-REG_CFG] Register read addr: 0x%0h data: 0x%0h", $time, paddr, prdata);
        end
    end

endmodule
