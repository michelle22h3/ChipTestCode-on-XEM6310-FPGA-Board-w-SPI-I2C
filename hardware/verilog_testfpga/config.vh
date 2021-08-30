
`ifndef __CONFIG_VH__
`define __CONFIG_VH__

`define SW_RST_ADDR 8'h07
`define ITF_SEL_ADDR 8'h17

// WireOut
`define STA_CHIP_ADDR 8'h27
`define FIFOB_EMPTY_ADDR 8'h37
`define FIFOB_PROG_FULL_ADDR 8'h38
// TriggerIn
`define SPI_CONFIG_ADDR 8'h47

// PipeIn
`define FIFOA_IN_DATA_ADDR 8'h87

`define FIFOB_OUT_DATA_ADDR 8'hA7

// Number of endpoints requiring `okEH`
`define NUM_ENDPOINTS 5

`endif



