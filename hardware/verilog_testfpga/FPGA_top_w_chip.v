module FPGA_top_w_chip (
    input  wire [4:0] okUH,      // Host interface input signals
    output wire [2:0] okHU,      // Host interface output signals
    inout  wire [31:0] okUHU,    // Host interface bidirectional signals
    inout  wire okAA,            // Host interface bidirectional signal
    input  wire sys_clkn,        // System differential clock input (negative)
    input  wire sys_clkp,        // System differential clock input (positive)
    output wire [7:0] led,       // On board LED pins
    output wire i2c_scl,         // I2C   
    inout wire  i2c_sda,
    output wire spi_sck,         // SPI
    output wire spi_mosi,
    input wire  spi_miso,
    output wire spi_cs,
    output wire itf_sel,         // Selcetion of interface
    output wire chip_rstn,       // Chip reset signal: active low
    // ---- Control and status signals connected to chip ---- //
    input wire  sta_wei,         // sta_wei = 1 after writing all weights
    input wire  sta_act          // sta_act = 1 after input trigger
    // ---- Serial Communication Interface ---- //
);

`include "config.vh"
// -----------------------------------------------------------------------------
// Internal connections declaration
// -----------------------------------------------------------------------------
// System clock (Differential to single-ended buffer primitive by Xilinx)
wire  CLK_100M;                  // process clock
// Interface with FIFO and FPGA Logic
wire [31:0]              FIFOA_OUT;       // FIFO out
wire                     FIFOA_ren;       // Read enable
wire                     FIFOA_empty;     // FIFO empty
wire                     FIFOA_full;
wire [31:0]              FIFOB_IN;        // data write into fifo
wire                     FIFOB_wen;       // FIFO B Write enable
wire                     FIFOB_empty;
wire                     FIFOB_full;
wire                     FIFOB_prog_full;
wire [10:0]              FIFOB_prog_thresh;

IBUFGDS osc_clk(.O(CLK_100M), .I(sys_clkp), .IB(sys_clkn));
// `okHost` endpoints
wire okClk;
wire [112:0] okHE;
wire [64:0] okEH;

// `okWireOr` endpoints
wire [65*`NUM_ENDPOINTS-1:0] okEHx;

// `okWireIn` connections
wire [31:0] sw_rst;                          //---- Bit [0] is Software reset ----//
// `okWireIn` connections
wire [31:0] chip_rst_x;                      //---- Bit [0] is Chip reset ----//
assign chip_rstn = chip_rst_x[0];
// `okWireIn` connections
wire [31:0] itf_sel_x;                       //---- Bit [0] is itf_sel ----//
assign itf_sel = itf_sel_x[0];
// `okWireIn` connections
wire [31:0] fifob_thresh;                    //---- Bit [10:0]  ----//
assign FIFOB_prog_thresh = fifob_thresh[10:0];

// `okWireOut` connections
wire [64:0] okEHChipSTA;
wire [31:0] sta_chip;                        //---- Bit [0],[1] is status from chip ----//
assign sta_chip = {30'd0, sta_wei, sta_act}; // 2'b10 Write weight done; 2'b11 input trigger done
// `okWireOut` connections
wire [64:0] okEHFifobEmpty;
wire [31:0] FIFOB_empty_x;
assign FIFOB_empty_x = {31'd0, FIFOB_empty};
// `okWireOut` connections
wire [64:0] okEHFifobProgFull;
wire [31:0] FIFOB_prog_full_x;
assign FIFOB_prog_full_x = {31'd0, FIFOB_prog_full};

// `okTriggerIn` connections
wire [31:0] spi_config;                      //---- Bit [0] is SPI Master Config ----//

// `okPipeIn` endpoints
// FIFO Data input connections
wire [64:0] okEHFIFOAIn;
wire fifoa_in_write_en;
wire [31:0] fifoa_in_write_data;             // Data write to fifo_a

// `okPipeOut` endpoints
// FIFO data output connections
wire [64:0] okEHFIFOBOut;
wire fifob_out_read_en;
wire [31:0] fifob_out_read_data;             // Data read from fifo_b

// -----------------------------------------------------------------------------
// Assign on-board LED
// -----------------------------------------------------------------------------
assign led = ~ {FIFOB_prog_full, sw_rst[4:0], sta_wei, sta_act};  // 0 means no light
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
assign okEHx = {okEHChipSTA, okEHFifobEmpty, okEHFifobProgFull, okEHFIFOAIn, okEHFIFOBOut};
// -----------------------------------------------------------------------------
// Instantiation of `okWireIn`
// -----------------------------------------------------------------------------
// Software rst pin
okWireIn wireInSwRst(
    .okHE(okHE), 
    .ep_addr(`SW_RST_ADDR), 
    .ep_dataout(sw_rst)
    );

// Interface selsection
okWireIn wireInChipRst(
    .okHE(okHE), 
    .ep_addr(`CHIP_RST_ADDR), 
    .ep_dataout(chip_rst_x)
    );

// Interface selsection
okWireIn wireInItfSel(
    .okHE(okHE), 
    .ep_addr(`ITF_SEL_ADDR), 
    .ep_dataout(itf_sel_x)
    );

// FIFOB_THRESH
okWireIn wireFifobThresh(
    .okHE(okHE), 
    .ep_addr(`FIFOB_THRESH_ADDR), 
    .ep_dataout(fifob_thresh)
    );
// -----------------------------------------------------------------------------
// Instantiation of `okWireOut`
// -----------------------------------------------------------------------------
okWireOut wireOutStaChip(
    .okHE(okHE), 
    .okEH(okEHChipSTA),
    .ep_addr(`STA_CHIP_ADDR),
    .ep_datain(sta_chip)
);

okWireOut wireOutFifobEmpty(
    .okHE(okHE), 
    .okEH(okEHFifobEmpty),
    .ep_addr(`FIFOB_EMPTY_ADDR),
    .ep_datain(FIFOB_empty_x)
);

okWireOut wireOutFifobProgfull(
    .okHE(okHE), 
    .okEH(okEHFifobProgFull),
    .ep_addr(`FIFOB_PROG_FULL_ADDR),
    .ep_datain(FIFOB_prog_full_x)
);
// -----------------------------------------------------------------------------
// Instantiation of `okTriggerIn`
// -----------------------------------------------------------------------------
okTriggerIn triggerInSpiConfig(
    .okHE(okHE), 
    .ep_addr(`SPI_CONFIG_ADDR),
    .ep_clk(okClk),
    .ep_trigger(spi_config)
);
// -----------------------------------------------------------------------------
// Instantiation of `okPipeIn`
// -----------------------------------------------------------------------------
okPipeIn pipeInActIn(
.okHE       (okHE),                     // Control signals to the target endpoints
.okEH       (okEHFIFOAIn),              // Control signals from the target endpoints
.ep_addr    (`FIFOA_IN_DATA_ADDR),      // Endpoint address
.ep_dataout (fifoa_in_write_data),      // Pipe data output
.ep_write   (fifoa_in_write_en)         // Active high write enable
);

// -----------------------------------------------------------------------------
// Instantiation of `okPipeOut`
// -----------------------------------------------------------------------------
okPipeOut pipeOutActOut(
.okHE       (okHE),                       // Control signals to the target endpoints
.okEH       (okEHFIFOBOut),               // Control signals from the target endpoints
.ep_addr    (`FIFOB_OUT_DATA_ADDR),       // Endpoint address
.ep_datain  (fifob_out_read_data),        // Pipe data input
.ep_read    (fifob_out_read_en)           // Active high read enable
);

// -----------------------------------------------------------------------------
// Instantiation of input FIFO
// -----------------------------------------------------------------------------
FIFO_IN FIFO_Input_A (
.rst        (sw_rst[0]),                // FIFO reset (active high)
.clk        (okClk),                    // FIFO clock
.din        (fifoa_in_write_data),      // FIFO write data input
.wr_en      (fifoa_in_write_en),        // FIFO write enable (active high)
.rd_en      (FIFOA_ren),                // FIFO read enable (active high)
.dout       (FIFOA_OUT),                // FIFO read data output
.full       (FIFOA_full),               // FIFO full
.empty      (FIFOA_empty)               // FIFO empty
);
// -----------------------------------------------------------------------------
// Instantiation of output FIFO
// -----------------------------------------------------------------------------
FIFO_OUT FIFO_Output_B (
.rst        (sw_rst[0]),                // FIFO reset (active high)
.clk        (okClk),                    // FIFO clock 
.din        (FIFOB_IN),                 // FIFO write data input
.wr_en      (FIFOB_wen),                // FIFO write enable (active high)
.rd_en      (fifob_out_read_en),        // FIFO read enable (active high)
.dout       (fifob_out_read_data),      // FIFO read data output
.full       (FIFOB_full),               // FIFO full
.prog_full  (FIFOB_prog_full),          // FIFO full with 320 byte data
.prog_full_thresh  (FIFOB_prog_thresh), // FIFO full with 320 byte data
.empty      (FIFOB_empty)               // FIFO empty
);


fpga_top u_fpga_top(
    .CLK         (okClk        ),
    .rst_n       (~sw_rst[0]   ), //reset (active low)
    .FIFOA_OUT   (FIFOA_OUT    ),
    .FIFOA_ren   (FIFOA_ren    ),
    .FIFOA_empty (FIFOA_empty  ),
    .FIFOB_IN    (FIFOB_IN     ),
    .FIFOB_wen   (FIFOB_wen    ),
    .itf_sel     (itf_sel      ),
    .spi_config  (spi_config[0]),
    .i2c_scl     (i2c_scl      ),
    .i2c_sda     (i2c_sda      ),
    .spi_sck     (spi_sck      ),
    .spi_mosi    (spi_mosi     ),
    .spi_miso    (spi_miso     ),
    .spi_cs      (spi_cs       )
);
    
endmodule