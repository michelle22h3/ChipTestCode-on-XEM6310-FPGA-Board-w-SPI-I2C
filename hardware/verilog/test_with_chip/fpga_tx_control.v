// =============================================================================
// Filename: fpga_tx_control.v
// Author: WANG, Xiaomeng
// Affiliation: Hong Kong University of Science and Technonlogy
// =============================================================================
module fpga_tx_control (
    // Interface with FIFO
    input  wire                     CLK     ,        // process clock
    input  wire                     rst_n   ,        // reset of process clcok
    input  wire [31:0]              FIFOA_OUT,       // FIFO out
    output reg                      FIFOA_ren,       // Read enable
    input  wire                     FIFOA_empty,     // FIFO empty
    output wire [31:0]              FIFOB_IN,        // data write into fifo
    output reg                      FIFOB_wen,       // FIFO B Write enable
    // Interface with WireIn
    input  wire                     itf_sel,         // Selection of itf 
    // Interface with ---- fpga_i2c_master_tx.v ----
    input wire                      i2c_w_finish,    
    input wire [7:0]                i2c_rd_data_reg, 
    input wire                      i2c_rd_valid_flag,
    // Interface with ---- fpga_spi_master_tx.v ----
    input wire                      spi_w_finish,     
    input wire [7:0]                spi_rd_data_reg,
    input wire                      spi_rd_data_valid_flag,
    // Control signals to ITF_TX Module: common
    output reg                      itf_sel_d3,
    output reg [7:0]                addr_byte,       // Addr received from FIFO
    output reg [7:0]                data_byte,       // Data received from FIFO
    output reg                      WriteByteStart,
    output reg                      ReadByteStart
);
// =============================================================================
    // Declare inner registers
    reg        WriteorRead;      // 1 means write; 0 means read
    reg [7:0]  DataFromITF;
    // Declare state registers
    reg [3:0]  state_tx;
    reg [3:0]  state_tx_next;   // 4 bit register
    // Declare itf_sel regs
    reg             itf_sel_d1;
    reg             itf_sel_d2;
    
    // Declare signals of itf data tx
    wire            itf_w_finish;
    wire            itf_rdata_valid_flag;
    wire   [7:0]    itf_rdata;
    // I2C rd data
    // signal assignment   
    assign itf_w_finish  = (itf_sel_d3) ? spi_w_finish : i2c_w_finish;
    assign itf_rdata_valid_flag = (itf_sel_d3) ? spi_rd_data_valid_flag : i2c_rd_valid_flag;
    assign itf_rdata = (itf_sel_d3) ? spi_rd_data_reg : i2c_rd_data_reg ;

    assign FIFOB_IN = {16'd0, addr_byte, DataFromITF}; // Put addr on it for checking
// =============================================================================
////// ----------- Main code --------- ////////
localparam  STATE_IDLE            = 4'd0,   // Idle state
            STATE_FIFOAEn         = 4'd1,   // Enable FIFO A
            STATE_FIFOAEnOff      = 4'd2,   // Enable signal off
            STATE_ReadFIFOA       = 4'd3,   // Read data from FIFO_A
			STATE_TriggerWrite    = 4'd4,   // Trigger SPI or I2C master to write [7:0]addr with [7:0]data
		   	STATE_TriggerRead     = 4'd5,   // Trigger SPI or I2C master to read [7:0]data from [7:0]addr
            STATE_ITF_Write       = 4'd6,   // Wait for ITF to communicate
            STATE_ITF_Read        = 4'd7,   // Wait for ITF to read data back
            STATE_ReadITFOut      = 4'd8,   // Read data transmitted back from ITF
            STATE_WriteFIFOB      = 4'd9,   // Write ITF data into FIFOB 
            STATE_Occupy10        = 4'd10,
            STATE_Occupy11        = 4'd11,
            STATE_Occupy12        = 4'd12,
            STATE_Occupy13        = 4'd13,
            STATE_Occupy14        = 4'd14,
            STATE_Occupy15        = 4'd15;
            
// =============================================================================
// Reset and sequential logic
// =============================================================================
always @(posedge CLK or negedge rst_n) begin
 if (~rst_n) begin
    state_tx      <= STATE_IDLE;
    end 
else begin
    state_tx      <= state_tx_next;
    end
end
// ============================================================================= 
// Next state logic combinational            
// =============================================================================
always @(*)begin
    state_tx_next   = state_tx; //  Store the state by default
    case (state_tx)
        STATE_IDLE:begin
            if (~FIFOA_empty) begin
                state_tx_next   = STATE_FIFOAEn;
            end
        end

        STATE_FIFOAEn:begin
            state_tx_next   = STATE_FIFOAEnOff;
        end

        STATE_FIFOAEnOff: begin
            state_tx_next   = STATE_ReadFIFOA;
        end

        STATE_ReadFIFOA:begin
            if (WriteorRead) begin
                state_tx_next   = STATE_TriggerWrite;  // Goes to Write Operation
            end 
            else if (~WriteorRead)
            begin
                state_tx_next   = STATE_TriggerRead;  // Goes to Read Operation
            end
        end

        STATE_TriggerWrite:begin           
            state_tx_next   = STATE_ITF_Write;   

        end

        STATE_TriggerRead:begin
            state_tx_next   = STATE_ITF_Read;
        end

        STATE_ITF_Write:begin                           
           if (itf_w_finish) begin
               state_tx_next   = STATE_IDLE; 
            end     
        end

        STATE_ITF_Read:begin
            if (itf_rdata_valid_flag) begin
                state_tx_next   = STATE_ReadITFOut;   // ITF finish 1 byte data reading
            end
        end

        STATE_ReadITFOut:begin
            state_tx_next   = STATE_WriteFIFOB;     
        end

        STATE_WriteFIFOB:begin
            state_tx_next   = STATE_IDLE;
        end
        
        STATE_Occupy10: state_tx_next   = STATE_IDLE;
        STATE_Occupy11: state_tx_next   = STATE_IDLE;
        STATE_Occupy12: state_tx_next   = STATE_IDLE;
        STATE_Occupy13: state_tx_next   = STATE_IDLE;
        STATE_Occupy14: state_tx_next   = STATE_IDLE;
        STATE_Occupy15: state_tx_next   = STATE_IDLE;

    endcase
end

// ============================================================================= 
// Output logic             
// =============================================================================
always @(posedge CLK or negedge rst_n) begin
  if (~rst_n) begin
    FIFOA_ren        <= 1'b0;
    WriteorRead      <= 1'b0;
    addr_byte        <= 8'd0;
    data_byte        <= 8'd0;
    WriteByteStart   <= 1'b0;
    ReadByteStart    <= 1'b0;
    DataFromITF      <= 8'd0;
    FIFOB_wen        <= 1'b0;
    end
    else begin
        case (state_tx_next)
            STATE_IDLE: begin
                FIFOA_ren        <= 1'b0;
                WriteorRead      <= 1'b0;
                addr_byte        <= 8'd0;
                data_byte        <= 8'd0; 
                WriteByteStart   <= 1'b0;
                ReadByteStart    <= 1'b0;  
                DataFromITF      <= 8'd0;
                FIFOB_wen        <= 1'b0;
            end

            STATE_FIFOAEn:begin
                FIFOA_ren       <= 1'b1;
            end

            STATE_FIFOAEnOff: begin
                FIFOA_ren       <= 1'b0;
            end

            STATE_ReadFIFOA:begin
                addr_byte       <= FIFOA_OUT[15:8];
                data_byte       <= FIFOA_OUT[7:0];
                WriteorRead     <= FIFOA_OUT[16];
            end

            STATE_TriggerWrite:begin
                WriteByteStart  <= 1'b1;
            end

            STATE_TriggerRead:begin
                ReadByteStart   <= 1'b1;
            end

            STATE_ITF_Write:begin
                WriteByteStart  <= 1'b0;
            end

            STATE_ITF_Read:begin
                ReadByteStart   <= 1'b0;
            end

            STATE_ReadITFOut:begin
                DataFromITF     <= itf_rdata;
            end

            STATE_WriteFIFOB:begin
                FIFOB_wen       <= 1'b1;
            end

        endcase
    end   
end

// -------- itf_sel signal -------- //
always @ (posedge CLK or negedge rst_n) begin
    if (~rst_n) begin
        itf_sel_d1 <= 1'b0;
        itf_sel_d2 <= 1'b0;
        itf_sel_d3 <= 1'b0;
    end else begin
        itf_sel_d1 <= itf_sel;
        itf_sel_d2 <= itf_sel_d1;
        itf_sel_d3 <= itf_sel_d2;
    end
end
// -------------------------------- //

endmodule