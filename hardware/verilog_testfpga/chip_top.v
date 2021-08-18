module chip_top (
    input  wire                     CLK              ,// process clock
    input  wire                     rst_n            ,// reset of process clcok
    input  wire                     itf_sel          ,// select between I2C and SPI
    // Interface with I2C Slave
    input  wire                     i2c_scl          ,
    inout  wire                     i2c_sda          , // i2c_sda do out of the chip
    // Interface with SPI Slave
    input  wire                     spi_cs           ,
    input  wire                     spi_sck          ,
    input  wire                     spi_mosi         ,
    output wire                     spi_miso         ,
    // Satus and test signals
    output wire                     sta_wei,
    output wire                     sta_act
);
// itf <=> cfg_reg
wire [15:0]  reg_rdata         ;// Register rdata[7:0]
wire [7:0]   reg_addr          ;// Register address[7:0]
wire         reg_ce            ;// Register chip enable
wire         reg_we            ;// Register write enable
wire [7:0]   reg_wdata_l       ;// Register wdata[7:0]
wire [7:0]   reg_wdata_h       ;// Register wdata[15:8]

chip_itf_top u_chip_itf_top(
    .CLK              (CLK          ),
    .rst_n            (rst_n        ),
    .itf_sel          (itf_sel      ),
    .i2c_scl          (i2c_scl      ),
    .i2c_sda          (i2c_sda      ),
    .spi_cs           (spi_cs       ),
    .spi_sck          (spi_sck      ),
    .spi_mosi         (spi_mosi     ),
    .spi_miso         (spi_miso     ),
// Interface with cfg_reg
    .reg_rdata_0b     (reg_rdata[7:0] ),
    .reg_rdata_1b     (reg_rdata[15:8]),
    .reg_addr_0b      (reg_addr       ),
    .reg_ce           (reg_ce         ),
    .reg_we           (reg_we         ),
    .reg_wdata_0b     (reg_wdata_l    ),
    .reg_wdata_1b     (reg_wdata_h    )
);

cfg_digiblk u_cfg_digiblk(
    .clk             (CLK             ),
    .rst_n           (rst_n           ),
    .sta_wei_wr      ( ),
    .sta_act_wr      ( ),
    .sta_wei_wr_flag ( sta_wei ),
    .sta_act_wr_flag ( sta_act ),
    .cfg_act_dat_end ( ),
    .cfg_act_trigger ( ),
    .cfg_weight_drv  ( ),
    .cfg_adc_msbwait ( ),
    .cfg_adc_bitwait ( ),
    .cfg_adc_msb_loc ( ),
    .cfg_adc_signlen ( ),
    .cfg_adc_begin   ( ),
    .ctrl_wei_sft    ( ),
    .ctrl_act_sft    ( ),
    .ctrl_force_trig ( ),
    .ctrl_force_ww   ( ),
    .data_wei        ( ),
    .data_act        ( ),
    .data_out        ( ),
    .wei_sftout      ( ),
    .act_sftout      ( ),
    .reg_ce          (reg_ce              ),
    .reg_addr        (reg_addr            ),
    .reg_we          (reg_we              ),
    .reg_wdata       ({reg_wdata_h, reg_wdata_l}),
    .reg_rdata       (reg_rdata           ),
    .data_wei_vld    ( ),
    .loadw_st        ( ),
    .data_act_vld    ( ),
    .loada_st        ( ),
    .saout_ren       ( ),
    .testw_st        ( ),
    .testw_sft       ( ),
    .testa_sft       ( )
);


endmodule