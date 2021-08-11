module fpga_control (
    // Interface with FIFO
    input  wire                     CLK     ,        // process clock
    input  wire                     rst_n   ,        // reset of process clcok
    input  wire [31:0]              FIFOA_OUT,       // FIFO out
    output wire                     FIFOA_ren,       // Read enable
    input  wire                     FIFOA_empty,     // FIFO empty
    output wire [31:0]              FIFOB_IN,        // data write into fifo
    output wire                     FIFOB_wen,       // FIFO B Write enable
    // Interface with WireIn
    input  wire                     itf_sel,         // Selection of itf 
    input  wire                     spi_config, 
    // ---------- Interface to fpga_itf_top: I2C --------- //
    input wire   [31:0] i2c_rd_data,
    input wire          i2c_rd_valid,
    input wire          i2c_master_busy, // busy
    // output
    output wire  [6:0]  i2c_slave_addr,
    output wire         i2c_master_rw,
    output wire  [31:0] i2c_master_addr,
    output wire  [31:0] i2c_master_din,
    output wire         i2c_master_valid,
    output wire         i2aen,
    output wire  [1:0]  i2ac,
    output wire  [1:0]  i2dc,
    // --------- Interface to fpga_itf_top: SPI --------- //
    input   wire [7:0]  spim_prdata,
    input   wire        spin_int,
    input   wire        spim_busy,      // busy
    // output
    output  wire        spim_psel,
    output  wire        spim_penable,
    output  wire        spim_pwrite,
    output  wire [7:0]  spim_paddr,
    output  wire [7:0]  spim_pwdata,
    output  wire        spin_es
);

    wire         i2c_w_finish;
    wire [7:0]   i2c_rd_data_reg;
    wire         i2c_rd_valid_flag;
    wire         spi_w_finish;
    wire [7:0]   spi_rd_data_reg;
    wire         spi_rd_data_valid_flag;

    wire [7:0]   addr_byte;
    wire [7:0]   data_byte;
    wire         itf_sel_d3 ;
    wire         WriteByteStart;
    wire         ReadByteStart;

fpga_tx_control u_fpga_tx_control(
    .CLK                    (CLK                    ),
    .rst_n                  (rst_n                  ),
    .FIFOA_OUT              (FIFOA_OUT              ),
    .FIFOA_ren              (FIFOA_ren              ),
    .FIFOA_empty            (FIFOA_empty            ),
    .FIFOB_IN               (FIFOB_IN               ),
    .FIFOB_wen              (FIFOB_wen              ),
    .itf_sel                (itf_sel                ),
    .i2c_w_finish           (i2c_w_finish           ),
    .i2c_rd_data_reg        (i2c_rd_data_reg        ),
    .i2c_rd_valid_flag      (i2c_rd_valid_flag      ),
    .spi_w_finish           (spi_w_finish           ),
    .spi_rd_data_reg        (spi_rd_data_reg        ),
    .spi_rd_data_valid_flag (spi_rd_data_valid_flag ),
    .itf_sel_d3             (itf_sel_d3             ),
    .addr_byte              (addr_byte              ),
    .data_byte              (data_byte              ),
    .WriteByteStart         (WriteByteStart         ),
    .ReadByteStart          (ReadByteStart          )
);

fpga_i2cmaster_tx u_fpga_i2cmaster_tx(
    .CLK               (CLK               ),
    .rst_n             (rst_n             ),
    .itf_sel_d3        (itf_sel_d3        ),
    .addr_byte         (addr_byte         ),
    .data_byte         (data_byte         ),
    .WriteByteStart    (WriteByteStart    ),
    .ReadByteStart     (ReadByteStart     ),
    .i2c_w_finish      (i2c_w_finish           ),
    .i2c_rd_data_reg   (i2c_rd_data_reg   ),
    .i2c_rd_valid_flag (i2c_rd_valid_flag ),
    .i2c_master_busy   (i2c_master_busy   ),
    .i2c_rd_data       (i2c_rd_data       ),
    .i2c_rd_valid      (i2c_rd_valid      ),
    .i2c_slave_addr    (i2c_slave_addr    ),
    .i2c_master_rw     (i2c_master_rw     ),
    .i2c_master_addr   (i2c_master_addr   ),
    .i2c_master_din    (i2c_master_din    ),
    .i2c_master_valid  (i2c_master_valid  ),
    .i2aen             (i2aen             ),
    .i2ac              (i2ac              ),
    .i2dc              (i2dc              )
);

fpga_spimaster_tx u_fpga_spimaster_tx(
    .CLK                    (CLK                    ),
    .rst_n                  (rst_n                  ),
    .itf_sel_d3             (itf_sel_d3             ),
    .addr_byte              (addr_byte              ),
    .data_byte              (data_byte              ),
    .WriteByteStart         (WriteByteStart         ),
    .ReadByteStart          (ReadByteStart          ),
    .spi_config             (spi_config             ),
    .spi_w_finish           (spi_w_finish           ),
    .spi_rd_data_reg        (spi_rd_data_reg        ),
    .spi_rd_data_valid_flag (spi_rd_data_valid_flag ),
    .spim_busy              (spim_busy              ),
    .spim_prdata            (spim_prdata            ),
    .spin_int               (spin_int               ),
    .spim_psel              (spim_psel              ),
    .spim_penable           (spim_penable           ),
    .spim_pwrite            (spim_pwrite            ),
    .spim_paddr             (spim_paddr             ),
    .spim_pwdata            (spim_pwdata            ),
    .spin_es                (spin_es                )
);




endmodule