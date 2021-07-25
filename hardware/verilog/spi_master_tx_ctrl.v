// -----------------------------------------------------------------------------
// SPI master TX control logic
// -----------------------------------------------------------------------------

module SPIMasterTXCtrl #(parameter DATA_WIDTH = 8)                   // Default data width of FIFO
                        (input wire clk,                             // System clock
                         input wire rst,                             // System reset
                         input wire fifo_empty,                      // FIFO empty status flag
                         input wire [DATA_WIDTH-1:0] fifo_read_data, // FIFO read data port
                         input wire spi_tx_ready,                    // SPI master TX ready flag
                         output wire fifo_read_en,                   // FIFO read enable (active high)
                         output wire spi_tx_data_valid,              // SPI master data valid
                         output wire [DATA_WIDTH-1:0] spi_tx_data);  // SPI master TX data port
    
    // ----------------------------------------
    // Finite state machine state declarations
    // ----------------------------------------
    localparam STATE_IDLE    = 2'd0; // Idle state (initial)
    localparam STATE_RD_FIFO = 2'd1; // Read FIFO state (generate fifo read enable)
    localparam STATE_SPI_TX  = 2'd2; // SPI master end TX data state (generate tx valid and corresponding data)
    
    
    // -----------------------------------------
    // State transfer in FSM
    // -----------------------------------------
    // State registers
    reg [1:0] state_reg;
    
    always @(posedge clk) begin
        if (rst) begin
            state_reg <= STATE_IDLE;
        end
        else begin
            case (state_reg)
                STATE_IDLE: begin
                    if (spi_tx_ready && ~fifo_empty) begin
                        // Start fetching FIFO if SPI master is ready to transmit and FIFO is not empty
                        state_reg <= STATE_RD_FIFO;
                    end
                end
                STATE_RD_FIFO: begin
                    state_reg <= STATE_SPI_TX;
                end
                STATE_SPI_TX: begin
                    state_reg <= STATE_IDLE;
                end
            endcase
        end
    end
    
    // -----------------------------------------
    // Output logic (Moore machine)
    // -----------------------------------------
    // Enable FIFO read when FIFO read state
    assign fifo_read_en = (state_reg == STATE_RD_FIFO);
    // Enable SPI transmit enable when SPI TX state
    assign spi_tx_data_valid = (state_reg == STATE_SPI_TX);
    assign spi_tx_data       = (state_reg == STATE_SPI_TX) ? fifo_read_data : {DATA_WIDTH{1'b0}};
    
endmodule
