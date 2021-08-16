module FPGA_top_w_chip (
    input  wire [4:0] okUH,      // Host interface input signals
    output wire [2:0] okHU,      // Host interface output signals
    inout  wire [31:0] okUHU,    // Host interface bidirectional signals
    inout  wire okAA,            // Host interface bidirectional signal
    input  wire sys_clkn,        // System differential clock input (negative)
    input  wire sys_clkp,        // System differential clock input (positive)
    output wire [7:0] led,       // On board LED pins
    // ---- Serial Communication Interface ---- //
    output wire i2c_scl,         // I2C   
    output wire i2c_sda,
    output wire spi_sck,         // SPI
    output wire spi_mosi,
    output wire spi_miso,
    output wire spi_cs,
    output wire itf_sel,         // Selcetion of interface
    // ---- Control and status signals connected to chip ---- //
    input wire  sta_wei,         // sta_wei = 1 after writing all weights
    input wire  sta_act          // sta_act = 1 after input trigger
);
`include "config.vh"
// -----------------------------------------------------------------------------
// Internal connections declaration
// -----------------------------------------------------------------------------
// System clock (Differential to single-ended buffer primitive by Xilinx)
wire  CLK_100M;                  // process clock
wire  CLK_6P4M;                  // Divided clock
wire  CLK_25P6M;                 // Divided clock

IBUFGDS osc_clk(.O(CLK_100M), .I(sys_clkp), .IB(sys_clkn));
// `okHost` endpoints
wire okClk;
wire [112:0] okHE;
wire [64:0] okEH;

// `okWireOr` endpoints
wire [65*`NUM_ENDPOINTS-1:0] okEHx;

// `okWireIn` connections
wire [31:0] sw_rst;                       //---- Bit [0] is Software reset ----//
wire [31:0] itf_sel_x;                    //---- Bit [0] is itf_sel ----//
assign itf_sel = itf_sel_x[0];

// `okWireOut` connections
wire [64:0] okEHChipSTA;
wire [31:0] sta_chip;                     //---- Bit [0],[1] is status from chip ----//
assign sta_chip = {30'd0, sta_wei, sta_act}; // 2'b10 Write weight done; 2'b11 input trigger done
// `okWireOut` connections
wire [64:0] okEHFifobEmpty;
wire [31:0] FIFOB_empty_x;
assign FIFOB_empty_x = {31'd0, FIFOB_empty};
// `okTriggerIn` connections
wire [31:0] spi_config;                   //---- Bit [0] is SPI Master Config ----//

// `okPipeIn` endpoints
// FIFO Data input connections
wire [64:0] okEHFIFOAIn;
wire fifoa_in_write_en;
wire [31:0] fifoa_in_write_data;          // Data write to fifo_a

// `okPipeOut` endpoints
// FIFO data output connections
wire [64:0] okEHFIFOBOut;
wire fifob_out_read_en;
wire [31:0] fifob_out_read_data;          // Data read from fifo_b

// Interface with FIFO and FPGA Logic
wire [31:0]              FIFOA_OUT;       // FIFO out
wire                     FIFOA_ren;       // Read enable
wire                     FIFOA_empty;     // FIFO empty
wire                     FIFOA_full;
wire [31:0]              FIFOB_IN;        // data write into fifo
wire                     FIFOB_wen;       // FIFO B Write enable
wire                     FIFOB_empty;
wire                     FIFOB_full;
// -----------------------------------------------------------------------------
// Assign on-board LED
// -----------------------------------------------------------------------------
assign led = ~ {~sw_rst[0], 5'd0, sta_wei, sta_act};  // Led is 0 enable
// -----------------------------------------------------------------------------
// Instantiation of Clk divider
// -----------------------------------------------------------------------------
CLK_DIV CLK_DIV_uut
(
.CLK_IN1    (CLK_100M),             // Clock in ports
.CLK_OUT1   (CLK_6P4M),             // Clock out port 1
.CLK_OUT2   (CLK_25P6M)             // Clock out port 2
);
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
assign okEHx = {okEHChipSTA, okEHFifobEmpty, okEHFIFOAIn, okEHFIFOBOut};
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
okWireIn wireInItfSel(
    .okHE(okHE), 
    .ep_addr(`ITF_SEL_ADDR), 
    .ep_dataout(itf_sel_x)
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
// -----------------------------------------------------------------------------
// Instantiation of `okTriggerIn`
// -----------------------------------------------------------------------------
okTriggerIn triggerInSpiConfig(
    .okHE(okHE), 
    .ep_addr(`SPI_CONFIG_ADDR),
    .ep_clk(CLK_6P4M),
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
.wr_clk     (okClk),                    // FIFO write side clock domain
.rd_clk     (CLK_6P4M),                 // FIFO read side clock domain
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
FIFO_IN FIFO_Output_B (
.rst        (sw_rst[0]),                // FIFO reset (active high)
.wr_clk     (CLK_6P4M),                 // FIFO write side clock domain
.rd_clk     (okClk),                    // FIFO read side clock domain
.din        (FIFOB_IN),                 // FIFO write data input
.wr_en      (FIFOB_wen),                // FIFO write enable (active high)
.rd_en      (fifob_out_read_en),        // FIFO read enable (active high)
.dout       (fifob_out_read_data),      // FIFO read data output
.full       (FIFOB_full),               // FIFO full
.empty      (FIFOB_empty)               // FIFO empty
);

fpga_top u_fpga_top(
    .CLK         (CLK_6P4M     ),
    .rst_n       (~sw_rst[0]   ), //reset (active low)
    .FIFOA_OUT   (FIFOA_OUT    ),
    .FIFOA_ren   (FIFOA_ren    ),
    .FIFOA_empty (FIFOA_empty  ),
    .FIFOB_IN    (FIFOB_IN     ),
    .FIFOB_wen   (FIFOB_wen    ),
    .sta_wei     (sta_wei      ),
    .sta_act     (sta_act      ),
    .itf_sel     (itf_sel      ),
    .spi_config  (spi_config[0]),
    .i2c_scl     (i2c_scl      ),
    .i2c_sda     (i2c_sda      ),
    .spi_sck     (spi_sck      ),
    .spi_mosi    (spi_mosi     ),
    .spi_miso    (spi_miso     ),
    .spi_cs      (spi_cs       )
);


chip_top u_chip_top(
    .CLK      (CLK_6P4M ),
    .rst_n    (~sw_rst[0]), //reset (active low)
    .itf_sel  (itf_sel  ),
    .i2c_scl  (i2c_scl  ),
    .i2c_sda  (i2c_sda  ),
    .spi_cs   (spi_cs   ),
    .spi_sck  (spi_sck  ),
    .spi_mosi (spi_mosi ),
    .spi_miso (spi_miso ),
    .sta_wei  (sta_wei  ),
    .sta_act  (sta_act  )
);
    
endmodule