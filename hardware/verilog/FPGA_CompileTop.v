// -----------------------------------------------------------------------------
// FPGA top level design.
// Reference: https://opalkelly.com/examples/hdl-framework-usb-3-0/#tab-verilog
// -----------------------------------------------------------------------------

module FPGATop (input wire [4:0] okUH,       // Host interface input signals
                output wire[2:0] okHU,       // Host interface output signals
                inout wire [31:0] okUHU,     // Host interface bidirectional signals
                inout wire okAA,             // Host interface bidirectional signal
                input wire sys_clkn,         // System differential clock input (negative)
                input wire sys_clkp,         // System differential clock input (positive)
                output wire [7:0] led,       // On board LED pins
                output wire A_SPI_CLK,       // ## Chip Interface: Activation SPI clock
                input wire A_SPI_MISO,       // Output activation RX SPI data (from slave to master)
                output wire A_SPI_MOSI,      // Input activation TX SPI data (from master to slave)
                output wire W_SPI_CLK,       // Weight SPI clock
                output wire W_SPI_MOSI,      // Weight TX SPI data (from master to slave)
                output wire Weight_CS_N,     // Weight SPI slave chip select (active low)
                output wire Activation_CS_N, // Activation SPI slave chip select (active low)
                output wire chip_start_mapw, // 2-cycle trigger signal indicating IC start the weight mapping
                output wire chip_start_calc, // 2-cycle trigger indicating IC start the calculation
                output wire CLK_100M,        // 100MHz clock from FPGA to IC
                output wire rst_n);          // Chip reset from FPGA to IC (active low)

`include "config.vh"

// -----------------------------------------------------------------------------
// Internal connections declaration
// -----------------------------------------------------------------------------
// System clock (Differential to single-ended buffer primitive by Xilinx)
// wire CLK_100M_SYS;

IBUFGDS osc_clk(.O(CLK_100M), .I(sys_clkp), .IB(sys_clkn));

// `okHost` endpoints
wire okClk;
wire [112:0] okHE;
wire [64:0] okEH;

// `okWireOr` endpoints
wire [65*`NUM_ENDPOINTS-1:0] okEHx;

// `okWireIn` connections
wire [31:0] sw_rst; // Software reset

// `okTriggerOut` connections
wire [64:0] okEHCalcDone;
wire [64:0] okEHActOutRxDone;

// `okPipeIn` endpoints
// Activation input connections
wire [64:0] okEHActIn;
wire act_in_write_en;
wire [31:0] act_in_write_data;
// Weight input connections
wire [64:0] okEHWeightIn;
wire weight_in_write_en;
wire [31:0] weight_in_write_data;

// `okPipeOut` endpoints
// Activation output connections
wire [64:0] okEHActOut;
wire act_out_read_en;
wire [31:0] act_out_read_data;

// Activation input data FIFO
wire act_in_fifo_full, act_in_fifo_empty;
wire [7:0] act_in_read_data;
wire act_in_read_en;

// Activation transfer SPI master
wire act_in_tx_data_valid;
wire [7:0] act_in_tx_data;
wire act_in_tx_ready;
wire act_out_rx_valid;
wire [7:0] act_out_rx_data;

// Weight input data FIFO
wire weight_fifo_full, weight_fifo_empty;
wire [7:0] weight_read_data;
wire weight_read_en;

// Weight transfer SPI master (No RX part)
wire weight_tx_data_valid;
wire [7:0] weight_tx_data;
wire weight_tx_ready;

// Activation output data FIFO
wire act_out_fifo_full, act_out_fifo_empty;
wire [7:0] act_out_write_data;
wire act_out_write_en;

// Main controller
wire act_out_rx_stage;
wire calc_done;
wire act_out_rx_done;
wire Activation_CS, Weight_CS;

// -----------------------------------------------------------------------------
// Assign on-board LED
// -----------------------------------------------------------------------------
wire [3:0] led_state;  // Indicator of current state of main control logic

assign led = ~ {led_state, sw_rst[3:0]};

// -----------------------------------------------------------------------------
// Instantiation of Clk divider
// -----------------------------------------------------------------------------
// wire clk_div_locked; // Indicate whether clk signal is locked (stable)
// ClkDiv clk_div
// (
// .CLK_IN1    (CLK_100M_SYS),         // Clock in ports
// .CLK_OUT1   (CLK_100M),             // Clock out ports
// .LOCKED     (clk_div_locked)        // Clock status
// );

// -----------------------------------------------------------------------------
// Instantiation of host interface
// -----------------------------------------------------------------------------
okHost hostIF(
.okUH       (okUH),                 // Host interface input signals
.okHU       (okHU),                 // Host interface output signals
.okUHU      (okUHU),                // Host interface bidirectional signals
.okClk      (okClk),                // Buffered copy of the host interface clock (100.8 MHz)
.okAA       (okAA),                 // Host interface bidirectional signal
.okHE       (okHE),                 // Control signals to the target endpoints
.okEH       (okEH)                  // Control signals from the target endpoints
);

// -----------------------------------------------------------------------------
// Instantiation of `okWireOR` to match the number of endpoints in your design
// -----------------------------------------------------------------------------
okWireOR #(.N(`NUM_ENDPOINTS)) wireOR (okEH, okEHx);
assign okEHx = {okEHActOut, okEHWeightIn, okEHActIn, okEHActOutRxDone, okEHCalcDone};

// -----------------------------------------------------------------------------
// Instantiation of `okWireIn`
// -----------------------------------------------------------------------------
// Software rst pin
okWireIn wireInSwRst(.okHE(okHE), .ep_addr(`SW_RST_ADDR), .ep_dataout(sw_rst));

// -----------------------------------------------------------------------------
// Instantiation of `okTriggerOut`
// -----------------------------------------------------------------------------
// Calculation finish trigger
okTriggerOut trigOutCalcDone(
.okHE       (okHE),                     // Control signals to the target endpoints
.okEH       (okEHCalcDone),             // Control signals from the target endpoints
.ep_addr    (`CALC_DONE_ADDR),          // Endpoint address
.ep_clk     (okClk),                    // Clock to which the trigger is synchronized
.ep_trigger ({31'b0, calc_done})        // Independent triggers to host
);

// Activation output finish trigger
okTriggerOut trigOutActOutRxDone(
.okHE       (okHE),                     // Control signals to the target endpoints
.okEH       (okEHActOutRxDone),         // Control signals from the target endpoints
.ep_addr    (`ACT_OUT_RX_DONE_ADDR),    // Endpoint address
.ep_clk     (okClk),                    // Clock to which the trigger is synchronized
.ep_trigger ({31'b0, act_out_rx_done})  // Independent triggers to host
);

// -----------------------------------------------------------------------------
// Instantiation of `okPipeIn` (TODO: consider to use `okBTPipeIn`)
// -----------------------------------------------------------------------------
// Activation input pipe data
okPipeIn pipeInActIn(
.okHE       (okHE),                     // Control signals to the target endpoints
.okEH       (okEHActIn),                // Control signals from the target endpoints
.ep_addr    (`ACT_IN_DATA_ADDR),        // Endpoint address
.ep_dataout (act_in_write_data),        // Pipe data output
.ep_write   (act_in_write_en)           // Active high write enable
);
// Weight input pipe data
okPipeIn pipeInWeightIn(
.okHE       (okHE),                     // Control signals to the target endpoints
.okEH       (okEHWeightIn),             // Control signals from the target endpoints
.ep_addr    (`WEIGHT_DATA_ADDR),        // Endpoint address
.ep_dataout (weight_in_write_data),     // Pipe data output
.ep_write   (weight_in_write_en)        // Active high write enable
);

// -----------------------------------------------------------------------------
// Instantiation of `okPipeOut` (TODO: consider to use `okBTPipeOut`)
// -----------------------------------------------------------------------------
// Activation output pipe data
okPipeOut pipeOutActOut(
.okHE       (okHE),                     // Control signals to the target endpoints
.okEH       (okEHActOut),               // Control signals from the target endpoints
.ep_addr    (`ACT_OUT_DATA_ADDR),       // Endpoint address
.ep_datain  (act_out_read_data),        // Pipe data input
.ep_read    (act_out_read_en)           // Active high read enable
);

// -----------------------------------------------------------------------------
// Instantiation of input activation FIFO
// -----------------------------------------------------------------------------
ActInFIFO act_in_fifo (
.rst        (sw_rst[0]),                // FIFO reset (active high)
.wr_clk     (okClk),                    // FIFO write side clock domain
.rd_clk     (CLK_100M),                 // FIFO read side clock domain
.din        (act_in_write_data),        // FIFO write data input
.wr_en      (act_in_write_en),          // FIFO write enable (active high)
.rd_en      (act_in_read_en),           // FIFO read enable (active high)
.dout       (act_in_read_data),         // FIFO read data output
.full       (act_in_fifo_full),         // FIFO full
.empty      (act_in_fifo_empty)         // FIFO empty
);

------------------------------------------------------------------------------------------
// Instantiation of output activation FIFO
// Activation SPI master writes the `MISO` data to FIFO and `pipeOutActOut` reads the FIFO data
// ---------------------------------------------------------------------------------------------
ActOutFIFO act_out_fifo (
.rst        (sw_rst[0]),            // FIFO reset (active high)
.wr_clk     (CLK_100M),             // FIFO write side clock domain
.rd_clk     (okClk),                // FIFO read side clock domain
.din        (act_out_write_data),   // FIFO write data input
.wr_en      (act_out_write_en),     // FIFO write enable (active high)
.rd_en      (act_out_read_en),      // FIFO read enable (active high)
.dout       (act_out_read_data),    // FIFO read data output
.full       (act_out_fifo_full),    // FIFO full
.empty      (act_out_fifo_empty)    // FIFO empty
);


// ---------------------------------------------------------------------------------------------
// Miscellaneous connections to IC chip
// ---------------------------------------------------------------------------------------------
assign rst_n           = ~sw_rst[0];            // IC reset is configured by host interface
assign Activation_CS_N = ~Activation_CS;
assign Weight_CS_N     = ~Weight_CS;

endmodule
