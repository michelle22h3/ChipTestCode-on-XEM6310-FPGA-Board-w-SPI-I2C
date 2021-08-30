// =============================================================================
// Filename: fpga_i2cmaster_tx.v
// Author: WANG, Xiaomeng
// Affiliation: Hong Kong University of Science and Technonlogy
// =============================================================================
//---------- I2C Master Write/Read 1 byte ----------- //
module fpga_i2cmaster_tx (
    input  wire         CLK,                     // process clock
    input  wire         rst_n,                   // reset of process clcok
    // --- Interface with fpga_tx_control.v ---  //
    input wire          itf_sel_d3,              // Selection of itf 
    input wire   [7:0]  addr_byte,               // Addr received from FIFO
    input wire   [7:0]  data_byte,               // Data received from FIFO
    input wire          WriteByteStart,
    input wire          ReadByteStart,

    output reg          i2c_w_finish,
    output reg  [7:0]   i2c_rd_data_reg, 
    output reg          i2c_rd_valid_flag,
    // --- Interface to fpga_itf_top: I2C Master-inputs --- //
    input wire          i2c_master_busy,
    input wire  [31:0]  i2c_rd_data,
    input wire          i2c_rd_valid,
    // --- Interface to fpga_itf_top: I2C Master-outputs --- //
    output reg  [6:0]   i2c_slave_addr,
    output reg          i2c_master_rw,
    output reg  [31:0]  i2c_master_addr,
    output reg  [31:0]  i2c_master_din,
    output reg          i2c_master_valid,
    output reg          i2aen,
    output reg  [1:0]   i2ac,
    output reg  [1:0]   i2dc
);
// =============================================================================
    reg [3:0] state_i2c;
    reg [3:0] state_i2c_next;

    wire start_write;
    wire start_read;

    assign start_write  = (~itf_sel_d3) & WriteByteStart;
    assign start_read   = (~itf_sel_d3) & ReadByteStart;
// =============================================================================
////// ----------- Main code --------- ////////
localparam STATE_IDLE        = 4'd0,
           STATE_WriteSelect = 4'd1,
           STATE_ReadSelect  = 4'd2,
           STATE_WriteEN     = 4'd3,
           STATE_WriteWaitA  = 4'd4,
           STATE_WriteWaitB  = 4'd5,
           STATE_WriteWaitC  = 4'd6,
           STATE_ReadEN      = 4'd7,
           STATE_ReadWaitA   = 4'd8,
           STATE_ReadData    = 4'd9,
           STATE_ReadWaitB   = 4'd10,
           STATE_ReadWaitC   = 4'd11,
           STATE_Occupy12    = 4'd12,
           STATE_Occupy13    = 4'd13,
           STATE_Occupy14    = 4'd14,
           STATE_Occupy15    = 4'd15;

assign tx_i2c_busy  = (state_i2c!= STATE_IDLE);    
// =============================================================================
// Reset and sequential logic
// =============================================================================
always @(posedge CLK or negedge rst_n) begin
 if (~rst_n) begin
    state_i2c      <= STATE_IDLE;
    end 
else begin
    state_i2c      <= state_i2c_next;
    end
end
// ============================================================================= 
// Next state logic combinational            
// =============================================================================
always @(*) begin
    state_i2c_next  = state_i2c; // Combinational logic: Default value
    case (state_i2c)
    STATE_IDLE: begin
        if (start_write) begin
            state_i2c_next  = STATE_WriteSelect;
        end
        else if (start_read) begin  
            state_i2c_next  = STATE_ReadSelect; 
        end
    end

    STATE_WriteSelect: begin
        if (~i2c_master_busy) begin
         state_i2c_next  = STATE_WriteEN;   
        end  
    end

    STATE_ReadSelect: begin
        if (~i2c_master_busy) begin           // Because after data_valid, it still takes
        state_i2c_next  = STATE_ReadEN;       // several cycles for i2c master to settle down
        end
    end

    STATE_WriteEN: begin
        state_i2c_next  = STATE_WriteWaitA;   // Wait for I2C Master to start working
    end

    STATE_WriteWaitA: begin
        state_i2c_next  = STATE_WriteWaitB;
    end

    STATE_WriteWaitB: begin
        if (~i2c_master_busy) begin           // Wait for I2C Master finish writing 1 byte
            state_i2c_next  = STATE_WriteWaitC;
        end
    end

    STATE_WriteWaitC: begin                   //  Generate a flag signal of finishing writing
        state_i2c_next  = STATE_IDLE;
    end

    STATE_ReadEN: begin
        state_i2c_next  = STATE_ReadWaitA;
    end

    STATE_ReadWaitA: begin
        if (i2c_rd_valid) begin
            state_i2c_next  = STATE_ReadData;
        end
    end

    STATE_ReadData: begin
        state_i2c_next  = STATE_ReadWaitB;
    end

    STATE_ReadWaitB: begin
        state_i2c_next  = STATE_ReadWaitC;
    end

    STATE_ReadWaitC: begin
        state_i2c_next  = STATE_IDLE;
    end

    STATE_Occupy12: state_i2c_next   = STATE_IDLE;
    STATE_Occupy13: state_i2c_next   = STATE_IDLE;
    STATE_Occupy14: state_i2c_next   = STATE_IDLE;
    STATE_Occupy15: state_i2c_next   = STATE_IDLE;

    endcase
end
// ============================================================================= 
// Output logic             
// =============================================================================
always @(posedge CLK or negedge rst_n) begin
    if (~rst_n) begin
        // --- Interface with fpga_tx_control.v ---  //
        i2c_w_finish        <= 1'b0;
        i2c_rd_data_reg     <= 8'd0;
        i2c_rd_valid_flag   <= 1'b0;
        // --- Interface to fpga_itf_top: I2C Master-outputs --- //
        i2c_slave_addr      <= 7'h2C;
        i2c_master_rw       <= 1'b0;
        i2c_master_addr     <= 32'd0;
        i2c_master_din      <= 32'd0;
        i2c_master_valid    <= 1'b0;
        i2aen               <= 1'b1;  // XJ: 1'b1: send addr & data; 1'b0: send data only
        i2ac                <= 2'b00; // XJ: address bit-width; 2'b00: 8bit; 2'b01: 16bit etc.
        i2dc                <= 2'b00; // XJ: data bit-width; 2'b00: 8bit; 2'b01: 16bit etc. 
    end
    else begin
        case (state_i2c_next)
            STATE_IDLE:begin
                // --- Interface with fpga_tx_control.v ---  //
                i2c_w_finish        <= 1'b0;
                i2c_rd_data_reg     <= 8'd0;
                i2c_rd_valid_flag   <= 1'b0;
                // --- Interface to fpga_itf_top: I2C Master-outputs --- //
                i2c_slave_addr      <= 7'h2C;
                i2c_master_rw       <= 1'b0;  // W or R
                i2c_master_addr     <= 32'd0; // Addr   
                i2c_master_din      <= 32'd0; // Data
                i2c_master_valid    <= 1'b0;
                i2aen               <= 1'b1;  // XJ: 1'b1: send addr & data; 1'b0: send data only
                i2ac                <= 2'b00; // XJ: address bit-width; 2'b00: 8bit; 2'b01: 16bit etc.
                i2dc                <= 2'b00; // XJ: data bit-width; 2'b00: 8bit; 2'b01: 16bit etc. 
            end

            STATE_WriteSelect: begin
                i2c_master_addr     <= {24'd0, addr_byte};
                i2c_master_din      <= {24'd0, data_byte};
                i2c_master_rw       <= 1'b1;  // Write: enable 1
            end 

            STATE_WriteEN: begin
                i2c_master_valid    <= 1'b1;
            end

            STATE_WriteWaitA: begin
                i2c_master_valid    <= 1'b0;
            end

            STATE_WriteWaitC: begin
                i2c_w_finish        <= 1'b1;
            end

            STATE_ReadSelect: begin
                i2c_master_addr     <= {24'd0, addr_byte};
                i2c_master_rw       <= 1'b0;  // Read: enable 0
            end

            STATE_ReadEN: begin
                i2c_master_valid    <= 1'b1;
            end
            
            STATE_ReadWaitA: begin
                i2c_master_valid    <= 1'b0;
            end

            STATE_ReadData:begin
                 i2c_rd_data_reg    <= i2c_rd_data[7:0];   
            end

            STATE_ReadWaitB: begin
                i2c_rd_valid_flag   <= 1'b1;
            end

            STATE_ReadWaitC: begin
                i2c_rd_valid_flag   <= 1'b0;
            end

        endcase
    end
end

endmodule