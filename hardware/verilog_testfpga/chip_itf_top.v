// -----------------------------------------------------------------------------
// MODULE NAME : itf_top 
// DESCRIPTION : 
//     Interface (I2C and SPI) to register list interface         
//
// -----------------------------------------------------------------------------
// REVISION HISTORY
// VERSION    DATE        AUTHOR      DESCRIPTION
//   1.0        2021         XJ           
// 
// -----------------------------------------------------------------------------

module chip_itf_top(
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
    // Interface with cfg_reg
    input  wire [7:0]               reg_rdata_0b     ,// Register rdata[7:0]
    input  wire [7:0]               reg_rdata_1b     ,// Register rdata[15:8]
    output wire [7:0]               reg_addr_0b      ,// Register address[7:0]
    output wire                     reg_ce           ,// Register chip enable
    output wire                     reg_we           ,// Register write enable
    output wire [7:0]               reg_wdata_0b     ,// Register wdata[7:0]
    output wire [7:0]               reg_wdata_1b     // Register wdata[15:8]

);
// *****************************************************************************
// DEFINE LOCAL PARAMETER  
// *****************************************************************************
localparam I2C_SLAVE_ADDR = 7'h2C;
wire i2c_sda_oe;
wire i2c_sda_oen;
wire i2c_sda_out;
wire i2c_sda_in;
assign i2c_sda_oen = ~i2c_sda_oe;
assign i2c_sda = (~i2c_sda_oen) ? i2c_sda_out : 1'bZ;  //sda as input
assign i2c_sda_in = (~i2c_sda_oen) ? 1'b1 : i2c_sda;   //sda as output
// *****************************************************************************
// DEFINE INTERNAL SIGNALS
// *****************************************************************************
wire [7:0]      i2c_addr;     
wire [7:0]      i2c_rdata;   
wire [7:0]      i2c_wdata;  
wire            i2c_wr;    

wire [7:0]      spi_addr;     
wire [7:0]      spi_rdata;   
wire [7:0]      spi_wdata;  
wire            spi_wr;    

wire [7:0]      itf_addr;     
wire [7:0]      itf_rdata;   
wire [7:0]      itf_wdata;  
wire            itf_wr;    

reg             itf_sel_d1;
reg             itf_sel_d2;
reg             itf_sel_d3;
// End of automatics
// *****************************************************************************
// INSTANTIATE MODULES 
// *****************************************************************************
i2c_slave  u_i2c_slave( 
             // Interface as I2C slave
             .scl         (i2c_scl          ),           
             .sda_in      (i2c_sda_in       ),       
             .sda_out     (i2c_sda_out      ),      
             .sda_oe      (i2c_sda_oe       ),       
             .slave_addr  (I2C_SLAVE_ADDR   ),         
             // Interface with register access
             .hclk        (CLK         ),           
             .hresetn     (rst_n            ),         
             .wr_en       (i2c_wr           ),        
             .addr        (i2c_addr[7:0]    ),     
             .wr_data     (i2c_wdata[7:0]   ),   
             .rd_data     (i2c_rdata[7:0]   )
           );   

spi_slave  u_spi_slave(
             // Interface as SPI Slave
             .cs               (spi_cs      ),// SPI chip select, active low
             .sck              (spi_sck     ),// SPI clock
             .mosi             (spi_mosi    ),// SPI master-out, slave-in
             .miso             (spi_miso    ),// SPI master-in, slave-out
             // Interface with register access
             .clk              (CLK    ),// system clock
             .rst_n            (rst_n       ),// system reset
             .rx_wr            (spi_wr      ),// SPI slave rx data byte collected done and write enable
             .rx_addr          (spi_addr    ),// SPI slave rx address
             .rx_data          (spi_wdata   ),// SPI slave rx data
             .tx_data          (spi_rdata   ) // SPI slave tx data
           );         

itf2reg  u_itf2reg( 
           .clk              (CLK      ),
           .rst_n            (rst_n         ),         
           // Interface reg access
           .itf_addr         (itf_addr      ),     
           .itf_wdata        (itf_wdata     ),    
           .itf_wr           (itf_wr        ),        
           .itf_rdata        (itf_rdata     ),    
           // Interface to register list
           //.reg_fin          (1'b1          ),       
           .reg_ce           (reg_ce        ),        
           .reg_we           (reg_we        ),       
           .reg_addr_0b      (reg_addr_0b   ),     
           .reg_wdata_0b     (reg_wdata_0b  ),    
           .reg_wdata_1b     (reg_wdata_1b  ),   
           .reg_rdata_0b     (reg_rdata_0b  ),    
           .reg_rdata_1b     (reg_rdata_1b  )
         );  
  
// *****************************************************************************
// MAIN CODE
// *****************************************************************************

always @ (posedge CLK or negedge rst_n) begin
    if (!rst_n) begin
        itf_sel_d1 <= 1'b0;
        itf_sel_d2 <= 1'b0;
        itf_sel_d3 <= 1'b0;
    end else begin
        itf_sel_d1 <= itf_sel;
        itf_sel_d2 <= itf_sel_d1;
        itf_sel_d3 <= itf_sel_d2;
    end
end

// selection between I2C and SPI
assign itf_wr    = (itf_sel_d3) ? spi_wr    : i2c_wr    ; 
assign itf_addr  = (itf_sel_d3) ? spi_addr  : i2c_addr  ; 
assign itf_wdata = (itf_sel_d3) ? spi_wdata : i2c_wdata ; 
assign i2c_rdata = (itf_sel_d3) ? 8'd0      : itf_rdata ; 
assign spi_rdata = (itf_sel_d3) ? itf_rdata : 8'd0      ; 
// *****************************************************************************
// ASSERTION
// *****************************************************************************
endmodule //END OF MODULE
