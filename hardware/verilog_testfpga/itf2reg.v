// -----------------------------------------------------------------------------
// MODULE NAME : itf2reg 
// DESCRIPTION : 
//     Interface to register access indirectly addressing         
//
// -----------------------------------------------------------------------------
// REVISION HISTORY
// VERSION    DATE        AUTHOR      DESCRIPTION
//   1.0        2021         XJ          
// 
// -----------------------------------------------------------------------------

module itf2reg(
    input  wire         clk              ,// system clock
    input  wire         rst_n            ,// system reset
    // Interface with ITF
    input  wire [7:0]   itf_addr         ,// ITF address
    input  wire [7:0]   itf_wdata        ,// ITF write data bus
    input  wire         itf_wr           ,// ITF write enable
    output reg  [7:0]   itf_rdata        ,// ITF read data bus
    // Interface with CFG
    //input  wire         reg_fin          ,// Register access finish
    input  wire [7:0]   reg_rdata_0b     ,// Register rdata[7:0]
    input  wire [7:0]   reg_rdata_1b     ,// Register rdata[15:8]
    output reg  [7:0]   reg_addr_0b      ,// Register address[7:0]
    output reg          reg_ce           ,// Register chip enable
    output reg          reg_we           ,// Register write enable
    output reg  [7:0]   reg_wdata_0b     ,// Register wdata[7:0]
    output reg  [7:0]   reg_wdata_1b      // Register wdata[15:8]
);
// *****************************************************************************
// DEFINE LOCAL PARAMETER 
// *****************************************************************************
//localparam STATUS           = 8'h00;
localparam OPERATION        = 8'h01;
localparam ADDR_0B          = 8'h02;
localparam WDATA_0B         = 8'h03;
localparam WDATA_1B         = 8'h04;
localparam RDATA_0B         = 8'h05;
localparam RDATA_1B         = 8'h06;
// *****************************************************************************
// DEFINE INTERNAL SIGNALS
// *****************************************************************************
//reg     slv_fin;
// *****************************************************************************
// INSTANTIATE MODULES 
// *****************************************************************************
// *****************************************************************************
// MAIN CODE
// *****************************************************************************
// W1C
//always @ (posedge clk or negedge rst_n) begin
//    if (!rst_n) begin
//        slv_fin <= 1'b0;
//    end else if ((itf_wr == 1'b1) && (itf_addr == STATUS)) begin
//        slv_fin <= itf_wdata[0] ? 1'b0 : slv_fin;
//    end else if (reg_fin == 1'b1) begin
//        slv_fin <=  1'b1;
//    end
//end
// W1P
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        reg_ce <=  1'b0;
    end else if ((itf_wr == 1'b1) && (itf_addr == OPERATION)) begin
        reg_ce <= itf_wdata[1];
    end else begin
        reg_ce <= 1'b0;
    end
end
// W1P
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        reg_we <= 1'b0;
    end else if ((itf_wr == 1'b1) && (itf_addr == OPERATION)) begin
        reg_we <= itf_wdata[0];
    end else begin
        reg_we <= 1'b0;
    end
end
// RW
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        reg_addr_0b <= 8'h00;
    end else if ((itf_wr == 1'b1) && (itf_addr == ADDR_0B)) begin
        reg_addr_0b <= itf_wdata;
    end
end
// RW
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        reg_wdata_0b <= 8'h00;
    end else if ((itf_wr == 1'b1) && (itf_addr == WDATA_0B)) begin
        reg_wdata_0b <= itf_wdata;
    end
end
// RW
always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        reg_wdata_1b <= 8'h00;
    end else if ((itf_wr == 1'b1) && (itf_addr == WDATA_1B)) begin
        reg_wdata_1b <= itf_wdata;
    end
end
// output mux
always @ (*) begin
    case(itf_addr)      
        //STATUS          : itf_rdata = {7'h00,slv_fin}; 
        OPERATION       : itf_rdata = {6'h00,reg_ce,reg_we}; 
        ADDR_0B         : itf_rdata = reg_addr_0b;
        WDATA_0B        : itf_rdata = reg_wdata_0b;
        WDATA_1B        : itf_rdata = reg_wdata_1b;
        RDATA_0B        : itf_rdata = reg_rdata_0b;
        RDATA_1B        : itf_rdata = reg_rdata_1b;
        default         : itf_rdata = 8'hab;
    endcase
end
// *****************************************************************************
// ASSERTION
// *****************************************************************************
endmodule //END OF MODULE

