module fpga_itf_top(
    // CLK and RST
    input wire CLK,
    input wire rst_n,
    // ---- I2C Interface to chip ---- //
    output wire scl,
    output wire csda,
    // ---- SPI Interface to chip ---- //
    output wire spi_sck,
    output wire spi_mosi,
    input wire  spi_miso,
    output wire spi_cs,
    // ----  Interface to FPGA Logic: I2C ---- // 
    output wire [31:0] i2c_rd_data,
    output wire        i2c_rd_valid,
    output wire        i2c_master_busy,
    // inputs
    input wire  [6:0]  i2c_slave_addr,
    input wire         i2c_master_rw,
    input wire  [31:0] i2c_master_addr,
    input wire  [31:0] i2c_master_din,
    input wire         i2c_master_valid,
    input  wire        i2aen,
    input  wire [1:0]  i2ac,
    input  wire [1:0]  i2dc,
    // ---- Interface to FPGA Logic: SPI ---- //
    input  wire        spim_psel,
    input  wire        spim_penable,
    input  wire        spim_pwrite,
    input  wire [7:0]  spim_paddr,
    input  wire [7:0]  spim_pwdata,
    output wire [7:0]  spim_prdata,
    output wire        spin_int,
    output wire        spim_busy,
    input  wire        spin_es

);
wire csda_out;
wire csda_oe;
assign csda = csda_oe ? csda_out : 1'bz;
assign csda_in = csda;

i2c_master u_i2c_master(
                        // Outputs
                        .scl           (scl              ),            
                        .sda_out       (csda_out         ),   
                        .sda_oe        (csda_oe          ),    
                        .rd_data       (i2c_rd_data      ),
                        .rd_valid      (i2c_rd_valid     ),
                        .stall         (i2c_master_busy  ),
                        // Inputs
                        .hclk          (CLK   ),
                        .hresetn       (rst_n            ), 
                        .slave_addr    (i2c_slave_addr   ),
                        .sda_in        (csda_in          ),  
                        .rw            (i2c_master_rw    ),
                        .addr          (i2c_master_addr  ),
                        .wr_data       (i2c_master_din   ),
                        .valid         (i2c_master_valid ),
                        .i2aen         (i2aen            ),// XJ: 1'b1: send addr & data; 1'b0: send data only
                        .i2ac          (i2ac             ),// XJ: address bit-width; 2'b00: 8bit; 2'b01: 16bit etc.
                        .i2dc          (i2dc             ) // XJ: data bit-width; 2'b00: 8bit; 2'b01: 16bit etc. 
                       );

spi_master u_spi_master(
                        .CLK      (CLK     ),            
                        .RESET    (~rst_n       ),
                        .psel     (spim_psel    ),
                        .penable  (spim_penable ),
                        .WE       (spim_pwrite  ),     
                        .RE       (spim_psel && ~spim_pwrite ),    
                        .ADDRD    (spim_paddr   ), 
                        .spim_busy (spim_busy),
                        .DATABI   (spim_pwdata  ), 
                        .DATAB    (spim_prdata  ),  
                        .SCK      (spi_sck      ),   
                        .MOSI     (spi_mosi     ), 
                        .MISO     (spi_miso     ), 
                        .INT      (spin_int     ),  
                        .SSn      (spi_cs       ), 
                        .ES       (spin_es      ) 
                       );

endmodule