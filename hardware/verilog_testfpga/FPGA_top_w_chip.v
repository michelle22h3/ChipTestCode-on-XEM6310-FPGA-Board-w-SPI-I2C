module FPGA_top_w_chip (
    // Interface with FIFO
    input  wire                     CLK     ,        // process clock
    input  wire                     rst_n   ,        // reset of process clcok
    input  wire [31:0]              FIFOA_OUT,       // FIFO out
    output wire                     FIFOA_ren,       // Read enable
    input  wire                     FIFOA_empty,     // FIFO empty
    output wire [31:0]              FIFOB_IN,        // data write into fifo
    output wire                     FIFOB_wen,       // FIFO B Write enable
    // Signals indicating operating state of chip
    output wire                     sta_wei,
    output wire                     sta_act,

    output wire                     i2c_scl,
    output wire                     i2c_sda,
    // Interface with WireIn, TriggerIn
    input  wire                     spi_config,   
    input  wire                     itf_sel          // Selection of itf 
);

    wire spi_sck;
    wire spi_mosi;
    wire spi_miso;
    wire spi_cs;
    
fpga_top u_fpga_top(
    .CLK         (CLK         ),
    .rst_n       (rst_n       ),
    .FIFOA_OUT   (FIFOA_OUT   ),
    .FIFOA_ren   (FIFOA_ren   ),
    .FIFOA_empty (FIFOA_empty ),
    .FIFOB_IN    (FIFOB_IN    ),
    .FIFOB_wen   (FIFOB_wen   ),
    .sta_wei     (sta_wei     ),
    .sta_act     (sta_act     ),
    .itf_sel     (itf_sel     ),
    .spi_config  (spi_config  ),
    .i2c_scl     (i2c_scl     ),
    .i2c_sda     (i2c_sda     ),
    .spi_sck     (spi_sck     ),
    .spi_mosi    (spi_mosi    ),
    .spi_miso    (spi_miso    ),
    .spi_cs      (spi_cs      )
);


chip_top u_chip_top(
    .CLK      (CLK      ),
    .rst_n    (rst_n    ),
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