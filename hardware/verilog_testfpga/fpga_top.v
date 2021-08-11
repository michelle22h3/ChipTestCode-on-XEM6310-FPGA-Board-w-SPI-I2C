// =============================================================================
// Filename: fpga_top.v
// Author: WANG, Xiaomeng
// Affiliation: Hong Kong University of Science and Technonlogy
// =============================================================================
module fpga_top (
    // Interface with FIFO
    input  wire                     CLK     ,        // process clock
    input  wire                     rst_n   ,        // reset of process clcok
    input  wire [31:0]              FIFOA_OUT,       // FIFO out
    output wire                     FIFOA_ren,       // Read enable
    input  wire                     FIFOA_empty,     // FIFO empty
    output wire [31:0]              FIFOB_IN,        // data write into fifo
    output wire                     FIFOB_wen,       // FIFO B Write enable
    // // Signals indicating operating state of chip
    input  wire                     sta_wei,
    input  wire                     sta_act,
    // Interface with WireIn
    input  wire                     itf_sel,         // Selection of itf 
    input  wire                     spi_config,      
    // ---- I2C Interface to chip ---- //
    output wire i2c_scl,
    output wire i2c_sda,
    // ---- SPI Interface to chip ---- //
    output wire spi_sck,
    output wire spi_mosi,
    input wire  spi_miso,
    output wire spi_cs
);
    //I2C master Interface
    wire        i2c_master_busy;
    wire        i2c_rd_valid;
    wire [31:0] i2c_rd_data;
    wire [6:0]  i2c_slave_addr;
    wire        i2c_master_rw;
    wire [31:0] i2c_master_addr;
    wire [31:0] i2c_master_din;
    wire        i2c_master_valid;
    wire        i2aen;
    wire  [1:0] i2ac;
    wire  [1:0] i2dc;
    // SPI master Interface
    wire [7:0]  spim_prdata;
    wire        spim_psel;
    wire        spim_penable;
    wire        spim_pwrite;
    wire [7:0]  spim_paddr;
    wire [7:0]  spim_pwdata;
    wire        spim_busy;
    wire        spin_int;
    wire        spin_es;

fpga_control u_fpga_control(
    .CLK              (CLK              ),
    .rst_n            (rst_n            ),
    .FIFOA_OUT        (FIFOA_OUT        ),
    .FIFOA_ren        (FIFOA_ren        ),
    .FIFOA_empty      (FIFOA_empty      ),
    .FIFOB_IN         (FIFOB_IN         ),
    .FIFOB_wen        (FIFOB_wen        ),
    .itf_sel          (itf_sel          ),
    .spi_config       (spi_config       ),
    .i2c_rd_data      (i2c_rd_data      ),
    .i2c_rd_valid     (i2c_rd_valid     ),
    .i2c_master_busy  (i2c_master_busy  ),
    .i2c_slave_addr   (i2c_slave_addr   ),
    .i2c_master_rw    (i2c_master_rw    ),
    .i2c_master_addr  (i2c_master_addr  ),
    .i2c_master_din   (i2c_master_din   ),
    .i2c_master_valid (i2c_master_valid ),
    .i2aen            (i2aen            ),
    .i2ac             (i2ac             ),
    .i2dc             (i2dc             ),
    .spim_prdata      (spim_prdata      ),
    .spin_int         (spin_int         ),
    .spim_busy        (spim_busy        ),
    .spim_psel        (spim_psel        ),
    .spim_penable     (spim_penable     ),
    .spim_pwrite      (spim_pwrite      ),
    .spim_paddr       (spim_paddr       ),
    .spim_pwdata      (spim_pwdata      ),
    .spin_es          (spin_es          )
);



fpga_itf_top u_fpga_itf_top(
    .CLK              (CLK              ),
    .rst_n            (rst_n            ),
    .scl              (i2c_scl          ),
    .csda             (i2c_sda          ),
    .spi_sck          (spi_sck          ),
    .spi_mosi         (spi_mosi         ),
    .spi_miso         (spi_miso         ),
    .spi_cs           (spi_cs           ),
    .i2c_rd_data      (i2c_rd_data      ),
    .i2c_rd_valid     (i2c_rd_valid     ),
    .i2c_master_busy  (i2c_master_busy  ),
    .i2c_slave_addr   (i2c_slave_addr   ),
    .i2c_master_rw    (i2c_master_rw    ),
    .i2c_master_addr  (i2c_master_addr  ),
    .i2c_master_din   (i2c_master_din   ),
    .i2c_master_valid (i2c_master_valid ),
    .i2aen            (i2aen            ),
    .i2ac             (i2ac             ),
    .i2dc             (i2dc             ),
    .spim_psel        (spim_psel        ),
    .spim_penable     (spim_penable     ),
    .spim_pwrite      (spim_pwrite      ),
    .spim_paddr       (spim_paddr       ),
    .spim_pwdata      (spim_pwdata      ),
    .spim_prdata      (spim_prdata      ),
    .spin_int         (spin_int         ),
    .spim_busy        (spim_busy        ),
    .spin_es          (spin_es          )
);



endmodule