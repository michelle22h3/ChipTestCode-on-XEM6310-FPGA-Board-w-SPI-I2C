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

// -----------------------------------------------------------------------------
// Control logic of activation input TX SPI master
// -----------------------------------------------------------------------------
SPIMasterTXCtrl act_tx_spi_ctrl
(
.clk                (CLK_100M),             // System clock
.rst                (sw_rst[0]),            // System reset
.fifo_empty         (act_in_fifo_empty),    // FIFO empty status flag
.fifo_read_data     (act_in_read_data),     // FIFO read data port
.spi_tx_ready       (act_in_tx_ready),      // SPI master TX ready flag
.fifo_read_en       (act_in_read_en),       // FIFO read enable (active high)
.spi_tx_data_valid  (act_in_tx_data_valid), // SPI master data valid
.spi_tx_data        (act_in_tx_data)        // SPI master TX data port
);

// -----------------------------------------------------------------------------
// Instantiation of SPI master interface of activation in and output
// -----------------------------------------------------------------------------
SPI_Master #(.SPI_MODE(1), .CLKS_PER_HALF_BIT(2)) act_spi_master
(
// Control/Data Signals,
.i_Rst_L    (~sw_rst[0]),           // FPGA Reset (active low)
.i_Clk      (CLK_100M),             // FPGA Clock

// TX (MOSI) Signals
.i_TX_Byte  (act_in_tx_data),       // Byte to transmit on MOSI
.i_TX_DV    (act_in_tx_data_valid), // Data Valid Pulse with i_TX_Byte
.o_TX_Ready (act_in_tx_ready),      // Transmit Ready for next byte

// RX (MISO) Signals
.o_RX_DV    (act_out_rx_valid),     // Data Valid pulse (1 clock cycle)
.o_RX_Byte  (act_out_rx_data),      // Byte received on MISO

// SPI Interface
.o_SPI_Clk  (A_SPI_CLK),            // SPI clock
.i_SPI_MISO (A_SPI_MISO),           // SPI input rx data (slave to master)
.o_SPI_MOSI (A_SPI_MOSI)            // SPI output tx data (master to slave)
);

// -----------------------------------------------------------------------------
// Instantiation of weight FIFO
// -----------------------------------------------------------------------------
WeightFIFO weight_fifo (
.rst        (sw_rst[0]),            // FIFO reset (active high)
.wr_clk     (okClk),                // FIFO write side clock domain
.rd_clk     (CLK_100M),             // FIFO read side clock domain
.din        (weight_in_write_data), // FIFO write data input
.wr_en      (weight_in_write_en),   // FIFO write enable (active high)
.rd_en      (weight_read_en),       // FIFO read enable (active high)
.dout       (weight_read_data),     // FIFO read data output
.full       (weight_fifo_full),     // FIFO full
.empty      (weight_fifo_empty)     // FIFO empty
);

// -----------------------------------------------------------------------------
// Control logic of weight TX SPI master
// -----------------------------------------------------------------------------
SPIMasterTXCtrl weight_tx_spi_ctrl
(
.clk                (CLK_100M),             // System clock
.rst                (sw_rst[0]),            // System reset
.fifo_empty         (weight_fifo_empty),    // FIFO empty status flag
.fifo_read_data     (weight_read_data),     // FIFO read data port
.spi_tx_ready       (weight_tx_ready),      // SPI master TX ready flag
.fifo_read_en       (weight_read_en),       // FIFO read enable (active high)
.spi_tx_data_valid  (weight_tx_data_valid), // SPI master data valid
.spi_tx_data        (weight_tx_data)        // SPI master TX data port
);

// -----------------------------------------------------------------------------
// Instantiation of SPI master interface of weight
// -----------------------------------------------------------------------------
SPI_Master #(.SPI_MODE(0), .CLKS_PER_HALF_BIT(2)) weight_spi_master
(
// Control/Data Signals,
.i_Rst_L    (~sw_rst[0]),           // FPGA Reset (active low)
.i_Clk      (CLK_100M),             // FPGA Clock

// TX (MOSI) Signals
.i_TX_Byte  (weight_tx_data),       // Byte to transmit on MOSI
.i_TX_DV    (weight_tx_data_valid), // Data Valid Pulse with i_TX_Byte
.o_TX_Ready (weight_tx_ready),      // Transmit Ready for next byte

// RX (MISO) Signals
.o_RX_DV    (/* floating */),       // Data Valid pulse (1 clock cycle)
.o_RX_Byte  (/* floating */),       // Byte received on MISO

// SPI Interface
.o_SPI_Clk  (W_SPI_CLK),            // SPI clock
.i_SPI_MISO (1'b0),                 // SPI input rx data (slave to master)
.o_SPI_MOSI (W_SPI_MOSI)            // SPI output tx data (master to slave)
);

// ---------------------------------------------------------------------------------------------
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
// Control logic of output activation RX SPI master
// ---------------------------------------------------------------------------------------------
SPIMasterRXCtrl act_out_rx_spi_ctrl
(
.clk                (CLK_100M),             // System clock
.rst                (sw_rst[0]),            // System reset (active high)
.spi_rx_data_valid  (act_out_rx_valid),     // SPI master rx data valid
.spi_rx_data        (act_out_rx_data),      // SPI master rx data
.act_out_rx_stage   (act_out_rx_stage),     // Flag for act output RX stage
.fifo_write_en      (act_out_write_en),     // FIFO write enable (active high)
.fifo_write_data    (act_out_write_data)    // FIFO write data
);

// ---------------------------------------------------------------------------------------------
// Main FPGA controller
// TODO: modify the parameter of drain cycles and compute cycles to match the actual behavior
// ---------------------------------------------------------------------------------------------
MainCtrl #(.DRAIN_TX_CYCLE(32), .CHIP_MAP_CYCLE(10000), .CHIP_COMP_CYCLE(10000)) main_ctrl
(
.clk                    (CLK_100M),             // System clock
.rst                    (sw_rst[0]),            // System reset
.weight_tx_data_valid   (weight_tx_data_valid), // Weight TX valid (1B sent to slave)
.act_in_tx_data_valid   (act_in_tx_data_valid), // Input activation TX valid (1B sent to slave)
.act_out_rx_valid       (act_out_rx_valid),     // Output activation RX valid (1B received by master)
.act_out_rx_stage       (act_out_rx_stage),     // Flag for receiving activation stage
.act_spi_slave_cs       (Activation_CS),        // Chip select of activation SPI slave interface
.weight_spi_slave_cs    (Weight_CS),            // Chip select of weight SPI slave interface
.start_mapw             (chip_start_mapw),           // 2-cycle trigger signal indicating IC start the weight mapping
.start_calc             (chip_start_calc),      // 2-cycle trigger to tell IC start calculation
.calc_done              (calc_done),            // 1-cycle trigger to tell host IC finishes calculation
.led_state              (led_state),            // Indicator of current state of main control logic
.act_out_rx_done        (act_out_rx_done)       // 1-cycle trigger to tell host IC sent out all calculated data
);

// ---------------------------------------------------------------------------------------------
// Miscellaneous connections to IC chip
// ---------------------------------------------------------------------------------------------
assign rst_n           = ~sw_rst[0];            // IC reset is configured by host interface
assign Activation_CS_N = ~Activation_CS;
assign Weight_CS_N     = ~Weight_CS;

endmodule
