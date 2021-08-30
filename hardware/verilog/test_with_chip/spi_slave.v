// -----------------------------------------------------------------------------
// MODULE NAME : spis.v 
// DESCRIPTION : 
//     SPI Slave to register access interface         
//     Support cpol=0 & cpha=0 where mosi is sampled at positive edge of sck
//     Assuming MSB is sent first
// -----------------------------------------------------------------------------
// REVISION HISTORY
// VERSION    DATE        AUTHOR      DESCRIPTION
//   1.0        2021         XJ            
// 
// -----------------------------------------------------------------------------

module spi_slave(
    // Interface as SPI Slave
    input  wire         cs               ,// SPI chip select, active low
    input  wire         sck              ,// SPI clock
    input  wire         mosi             ,// SPI master-out, slave-in
    output wire         miso             ,// SPI master-in, slave-out
    // Interface with register access
    input  wire         clk              ,// system clock
    input  wire         rst_n            ,// system reset
    output reg          rx_wr            ,// SPI slave rx data byte collected done and write enable
    output reg  [7:0]   rx_addr          ,// SPI slave rx address
    output reg  [7:0]   rx_data          ,// SPI slave rx data
    input  wire [7:0]   tx_data           // SPI slave tx data
);
// *****************************************************************************
// DEFINE LOCAL PARAMETER 
// *****************************************************************************

// *****************************************************************************
// DEFINE INTERNAL SIGNALS
// *****************************************************************************
reg           cs_d1          ;// cs delay at clk domain
reg           cs_d2          ;// cs_d1 delay at clk domain
reg           cs_d3          ;// cs_d2 delay at clk domain
reg           cs_d4          ;// cs_d3 delay at clk domain
reg           sck_d1         ;// sck delay at clk domain
reg           sck_d2         ;// sck_d1 delay at clk domain 
reg           sck_d3         ;// sck_d2 delay at clk domain 
reg           sck_d4         ;// sck_d3 delay at clk domain 
wire          sck_pedge      ;// sample point for SPI mode cpol^cpha = 0
wire          sck_nedge      ;// sample point for SPI mode cpol^cpha = 1
reg  [7:0]    rx_spdr        ;// rx spi shift data register
reg  [7:0]    tx_spdr        ;// rx spi shift data register
reg  [3:0]    bitcnt         ;// count mosi bit 0~8
wire          byte_rxd       ;// bitcunt==8
reg           rx_cnt         ;// rx data (one byte) count 0~1
wire          addr_rxd       ;// received address from tx data
wire          data_rxd       ;// received data from rx data
reg           addr_rxd_d1    ;// delay addr_rxd for tx data to be ready
reg           addr_rxd_d2    ;// delay addr_rxd for tx data to be ready
reg           tx_data_rdy    ;// tx_data ready to put to tx_spdr
// *****************************************************************************
// INSTANTIATE MODULES 
// *****************************************************************************

// *****************************************************************************
// MAIN CODE
// *****************************************************************************
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cs_d1 <= 1'b0;
        cs_d2 <= 1'b0;
        cs_d3 <= 1'b0;
        cs_d4 <= 1'b0;
    end else begin
        cs_d1 <= cs;
        cs_d2 <= cs_d1;
        cs_d3 <= cs_d2;
        cs_d4 <= cs_d3;
    end
end

always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sck_d1 <= 1'b0;
        sck_d2 <= 1'b0;
        sck_d3 <= 1'b0;
        sck_d4 <= 1'b0;
    end else begin
        sck_d1 <= sck;
        sck_d2 <= sck_d1;
        sck_d3 <= sck_d2;
        sck_d4 <= sck_d3;
    end
end

// at high-level of this signal, mosi is sampled and miso is updated 
assign sck_pedge = (sck_d3 && ~sck_d4 && ~cs_d4);
assign sck_nedge = (~sck_d3 && sck_d4 && ~cs_d4);

// collect rx data, assuming MSB first
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_spdr <=  8'd0;
    end else if (sck_pedge) begin
        rx_spdr <=  {rx_spdr[6:0], mosi};
    end else begin
        rx_spdr <=  rx_spdr;
    end
end

// shift tx data and assign the MSB to miso
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_spdr <=  8'd0;
    //end else if (addr_rxd_d2) begin
    end else if (tx_data_rdy && sck_nedge) begin
        tx_spdr <=  tx_data;
    end else if (sck_nedge) begin
        tx_spdr <=  {tx_spdr[6:0], 1'b0};
    end else begin
        tx_spdr <=  tx_spdr;
    end
end
assign miso = tx_spdr[7];

//always @ (posedge clk or negedge rst_n) begin
//    if (!rst_n) begin
//        miso <= 1'b0;
//    end else if (sck_pedge) begin
//        miso <= tx_spdr[7];
//    end else begin
//        miso <= miso;
//    end
//end

// count sampling bit
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bitcnt <=  4'd0;
    end else if (byte_rxd) begin
        bitcnt <=  4'd0;
    end else if (sck_pedge) begin
        bitcnt <=  bitcnt + 4'd1;
    end else begin
        bitcnt <=  bitcnt;
    end
end
assign byte_rxd = bitcnt[3];   // mark one byte is received

// count rx data to tell apart addr and data
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_cnt <= 1'b0;
    end else if (byte_rxd) begin
        rx_cnt <= ~rx_cnt;
    end else begin
        rx_cnt <= rx_cnt;
    end
end

// address received
assign addr_rxd = (byte_rxd && ~rx_cnt);
assign data_rxd = (byte_rxd && rx_cnt);

// delay addr_rxd as tx data ready
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        addr_rxd_d1 <= 1'b0;
        addr_rxd_d2 <= 1'b0;
    end else begin
        addr_rxd_d1 <= addr_rxd;
        addr_rxd_d2 <= addr_rxd_d1;
    end
end

always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_data_rdy <= 1'b0;
    end else if (sck_nedge) begin
        tx_data_rdy <= 1'b0;
    end else if (addr_rxd_d2) begin
        tx_data_rdy <= 1'b1;
    end else begin
        tx_data_rdy <= tx_data_rdy;
    end
end

// rx data collected done and write enable
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_wr <= 1'b0;
    end else begin
        rx_wr <= data_rxd;
    end
end

// rx data
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_data <= 8'd0;
    end else if (data_rxd) begin
        rx_data <= rx_spdr;
    end else begin
        rx_data <= rx_data;
    end
end

// rx addr
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_addr <= 8'd0;
    end else if (addr_rxd) begin
        rx_addr <= rx_spdr;
    end else begin
        rx_addr <= rx_addr;
    end
end

//assign tx_rd = (addr_rxd_d1);

// *****************************************************************************
// ASSERTION
// *****************************************************************************
endmodule //END OF MODULE

