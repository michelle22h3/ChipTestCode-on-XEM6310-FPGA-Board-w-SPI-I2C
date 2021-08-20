// =============================================================================
// Filename: fpga_i2cmaster_tx.v
// Author: WANG, Xiaomeng
// Affiliation: Hong Kong University of Science and Technonlogy
// =============================================================================
//---------- SPI Master Write/Read 1 byte ----------- //
module fpga_spimaster_tx (
    input  wire         CLK,      // process clock
    input  wire         rst_n,    // reset of process clcok
    // --- Interface with fpga_tx_control.v ---//
    input wire          itf_sel_d3,            // Selection of itf 
    input wire   [7:0]  addr_byte,             // Addr received from FIFO
    input wire   [7:0]  data_byte,             // Data received from FIFO
    input wire          WriteByteStart,
    input wire          ReadByteStart,
    input wire          spi_config,    

    output reg          spi_w_finish,
    output reg   [7:0]  spi_rd_data_reg,
    output reg          spi_rd_data_valid_flag,
    // Interface to fpga_itf_top: SPI
    input wire          spim_busy,  
    input wire [7:0]    spim_prdata,
    input wire          spin_int,
    // output
    output  reg         spim_psel,
    output  reg         spim_penable,
    output  reg         spim_pwrite,
    output  reg  [7:0]  spim_paddr,
    output  reg  [7:0]  spim_pwdata,
    output  reg         spin_es
);
// =============================================================================
    reg [4:0] state_spi;
    reg [4:0] state_spi_next;   

    wire start_write;
    wire start_read;

    assign start_write  = (itf_sel_d3) & WriteByteStart;
    assign start_read   = (itf_sel_d3) & ReadByteStart;

// =============================================================================
////// ----------- Main code --------- ////////
localparam STATE_IDLE           = 5'd0,
           STATE_WriteSelect    = 5'd1,    
           STATE_ReadSelect     = 5'd2,    
           STATE_WriteAddr      = 5'd3,
           STATE_WriteWaitA0    = 5'd4,
           STATE_WriteWaitA1    = 5'd5,
           STATE_WriteWaitA2    = 5'd6,
           STATE_WriteData      = 5'd7,
           STATE_WriteWaitB0    = 5'd8,
           STATE_WriteWaitB1    = 5'd9,
           STATE_WriteWaitB2    = 5'd10,
           STATE_WriteWaitB3    = 5'd11,

           STATE_ReadSendAddr   = 5'd12,
           STATE_ReadWaitA0     = 5'd13,
           STATE_ReadWaitA1     = 5'd14,
           STATE_ReadWaitA2     = 5'd15,
           STATE_ReadSendData   = 5'd16,
           STATE_ReadWaitB0     = 5'd17,
           STATE_ReadWaitB1     = 5'd18,
           STATE_ReadWaitB2     = 5'd19,
           STATE_ReadAskData    = 5'd20,
           STATE_ReadGetData    = 5'd21,

           STATE_ConfigSelect   = 5'd22,
           STATE_Config         = 5'd23,

           STATE_Occupy24       = 5'd24,
           STATE_Occupy25       = 5'd25,
           STATE_Occupy26       = 5'd26,
           STATE_Occupy27       = 5'd27,
           STATE_Occupy28       = 5'd28,
           STATE_Occupy29       = 5'd29,
           STATE_Occupy30       = 5'd30,
           STATE_Occupy31       = 5'd31;
           
// =============================================================================
// Reset and sequential logic
// =============================================================================
always @(posedge CLK or negedge rst_n) begin
 if (~rst_n) begin
    state_spi      <= STATE_IDLE;
    end 
else begin
    state_spi      <= state_spi_next;
    end
end
// ============================================================================= 
// Next state logic combinational            
// =============================================================================
always @(*) begin
    state_spi_next  = state_spi;  // Combinational logic: Default value
    case (state_spi)
        STATE_IDLE: begin
            if(start_write) begin
                state_spi_next  = STATE_WriteSelect;
            end
            else if (start_read) begin
                state_spi_next  = STATE_ReadSelect;
            end
            else if (spi_config) begin
                state_spi_next  = STATE_ConfigSelect;
            end
        end

        STATE_WriteSelect:begin
            state_spi_next  = STATE_WriteAddr;
        end

        STATE_WriteAddr: begin
            state_spi_next  = STATE_WriteWaitA0;
        end

        STATE_WriteWaitA0: begin
            state_spi_next  = STATE_WriteWaitA1;
        end

        STATE_WriteWaitA1: begin
            state_spi_next  = STATE_WriteWaitA2;
        end

        STATE_WriteWaitA2: begin
            if(~spim_busy) begin
                state_spi_next  = STATE_WriteData;
            end
        end

        STATE_WriteData: begin
            state_spi_next  = STATE_WriteWaitB0;
        end

        STATE_WriteWaitB0: begin
            state_spi_next  = STATE_WriteWaitB1;
        end

        STATE_WriteWaitB1: begin
            state_spi_next  = STATE_WriteWaitB2;
        end

        STATE_WriteWaitB2: begin
            if(~spim_busy) begin
                state_spi_next  = STATE_WriteWaitB3;
            end
        end

        STATE_WriteWaitB3: begin
            state_spi_next  = STATE_IDLE;
        end

        STATE_ReadSelect: begin
            state_spi_next  = STATE_ReadSendAddr;
        end

        STATE_ReadSendAddr: begin
            state_spi_next  = STATE_ReadWaitA0;
        end

        STATE_ReadWaitA0: begin
            state_spi_next  = STATE_ReadWaitA1;
        end

        STATE_ReadWaitA1: begin
            state_spi_next  = STATE_ReadWaitA2;
        end

        STATE_ReadWaitA2: begin
            if (~spim_busy) begin
                state_spi_next  = STATE_ReadSendData;
            end
        end

        STATE_ReadSendData: begin   // Send dummy data for shifting out results
            state_spi_next  = STATE_ReadWaitB0;
        end

        STATE_ReadWaitB0: begin
            state_spi_next  = STATE_ReadWaitB1;
        end

        STATE_ReadWaitB1: begin
            state_spi_next  = STATE_ReadWaitB2;
        end

        STATE_ReadWaitB2: begin
            if (~spim_busy) begin
                state_spi_next  = STATE_ReadAskData;
            end
        end

        STATE_ReadAskData: begin
            state_spi_next  = STATE_ReadGetData;
        end

        STATE_ReadGetData: begin
            state_spi_next  = STATE_IDLE;
        end

        STATE_ConfigSelect: begin
            state_spi_next  = STATE_Config;
        end

        STATE_Config: begin
            state_spi_next  = STATE_IDLE;
        end

        STATE_Occupy24: state_spi_next  = STATE_IDLE;
        STATE_Occupy25: state_spi_next  = STATE_IDLE;
        STATE_Occupy26: state_spi_next  = STATE_IDLE;
        STATE_Occupy27: state_spi_next  = STATE_IDLE;
        STATE_Occupy28: state_spi_next  = STATE_IDLE;
        STATE_Occupy29: state_spi_next  = STATE_IDLE;
        STATE_Occupy30: state_spi_next  = STATE_IDLE;
        STATE_Occupy31: state_spi_next  = STATE_IDLE;

    endcase
end
// ============================================================================= 
// Output logic             
// =============================================================================
always @(posedge CLK or negedge rst_n) begin
    if (~rst_n) begin
        // --- Interface with fpga_tx_control.v ---  //
        spi_rd_data_reg          <= 8'd0;
        spi_rd_data_valid_flag   <= 1'b0;
        // --- Interface to fpga_itf_top: I2C Master-outputs --- //
        spim_psel       <= 1'b0;     // Selection
        spim_penable    <= 1'b1;     // Enable pulse: active 0
        spim_pwrite     <= 1'b0;     // Write: enable 1
        spim_paddr      <= 8'd0;     // Addr
        spim_pwdata     <= 8'd0;     // Data
        spin_es         <= 1'b0;
        spi_w_finish    <= 1'b0;
    end
    else begin
        case (state_spi_next)
            STATE_IDLE: begin
                // --- Interface with fpga_tx_control.v ---  //
                spi_rd_data_reg          <= 8'd0;
                spi_rd_data_valid_flag   <= 1'b0;
                // --- Interface to fpga_itf_top: I2C Master-outputs --- //
                spim_psel       <= 1'b0;     // Selection
                spim_penable    <= 1'b1;     // Enable pulse: active 0
                spim_pwrite     <= 1'b0;     // Write: enable 1
                spim_paddr      <= 8'd0;     // Addr
                spim_pwdata     <= 8'd0;     // Data
                spin_es         <= 1'b0;  
                spi_w_finish    <= 1'b0;
            end

            STATE_WriteSelect: begin
                spim_psel       <= 1'b1;         // Selection
                spim_pwrite     <= 1'b1;         // Write: enable 1
                spim_paddr      <= 8'h04;        // SPDR_ADDR
                spim_pwdata     <= addr_byte;    // Addr to be transferred
            end
            
            STATE_WriteAddr: begin
                spim_penable    <= 1'b0;         // Enable
            end

            STATE_WriteWaitA0: begin
                spim_penable    <= 1'b1;         
                spim_pwdata     <= data_byte;   // Data to be transferred
            end

            STATE_WriteData: begin
                spim_penable    <= 1'b0;         // Enable
            end

            STATE_WriteWaitB0: begin
                spim_penable    <= 1'b1;      
            end

            STATE_WriteWaitB3: begin
               spi_w_finish     <= 1'b1;
            end

            STATE_ReadSelect: begin
                spim_psel       <= 1'b1;         // Selection
                spim_pwrite     <= 1'b1;         // Write addr into spi slave
                spim_paddr      <= 8'h04;        // SPDR_ADDR
                spim_pwdata     <= addr_byte;    // Addr to be transferred
            end

            STATE_ReadSendAddr: begin
                spim_penable    <= 1'b0;         // Enable pulse
            end

            STATE_ReadWaitA0: begin
                spim_penable    <= 1'b1;       
            end

            STATE_ReadSendData: begin
                spim_penable    <= 1'b0;         // Enable pulse up
            end                                  // Send out the same data

            STATE_ReadWaitB0: begin
                spim_penable    <= 1'b1;         
            end

            STATE_ReadAskData: begin
                spim_pwrite     <= 1'b0;         // Read data from SPI Master
            end

            STATE_ReadGetData: begin
                spi_rd_data_reg         <= spim_prdata;
                spi_rd_data_valid_flag  <= 1'b1;
            end

            STATE_ConfigSelect: begin
                spim_psel       <= 1'b1;         // Selection
                spim_pwrite     <= 1'b1;         // Write CONFIG into spi slave
                spim_paddr      <= 8'h02;        // SPCR_ADDR
                spim_pwdata     <= 8'hd3;        // Data to be transferred
            end

            STATE_Config: begin
                spim_penable    <= 1'b0;         // Enable pulse up
            end

        endcase
    end
end


endmodule