// -----------------------------------------------------------------------------
// SPI master RX control logic
// -----------------------------------------------------------------------------

module SPIMasterRXCtrl #(parameter DATA_WIDTH = 8)                      // Default data width of FIFO
                        (input wire clk,                                // System clock
                         input wire rst,                                // System reset (active high)
                         input wire spi_rx_data_valid,                  // SPI master rx data valid
                         input wire [DATA_WIDTH-1:0] spi_rx_data,       // SPI master rx data
                         input wire act_out_rx_stage,                   // Flag for act output RX stage
                         output wire fifo_write_en,                     // FIFO write enable (active high)
                         output wire [DATA_WIDTH-1:0] fifo_write_data); // FIFO write data
    
    // The logic is purely combinational
    assign fifo_write_en   = spi_rx_data_valid & act_out_rx_stage;
    assign fifo_write_data = spi_rx_data;
    
endmodule
