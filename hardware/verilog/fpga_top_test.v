module fpga_top_test(
    input  wire                    CLK,             // process clock
    input  wire                    rst_n,           // reset of process clcok
    input  wire [31:0]             FIFOA_OUT,       // FIFO out
    output reg                     FIFOA_ren,       // Read enable
    input  wire                    FIFOA_empty,     // FIFO empty
    output reg [31:0]              FIFOB_IN,        // data write into fifo
    output reg                     FIFOB_wen,       // FIFO B Write enable
    output reg                     Triggered

);
    reg [2:0]  state;
    reg [2:0]  state_next;   // 3 bit register
    reg [31:0] addr_byte;

localparam  STATE_IDLE            = 3'd0,   // Idle state
            STATE_FIFOAEn         = 3'd1,   // Enable FIFO A
            STATE_FIFOAEnOff      = 3'd2,   // Enable signal off
            STATE_ReadFIFOA       = 3'd3,   // Read data from FIFO_A
			STATE_TriggerWrite    = 3'd4,   // 
		   	STATE_WriteFIFOB      = 3'd5,   // 
            STATE_Occupy6         = 3'd6,   // Wait 
            STATE_Occupy7         = 3'd7;   // Wait 

// =============================================================================
always @(posedge CLK or negedge rst_n) begin
 if (~rst_n) begin
    state      <= STATE_IDLE;
    end 
else begin
    state      <= state_next;
    end
end  

// ============================================================================= 
// Next state logic combinational            
// =============================================================================
always @(*)begin
    state_next   = state; //  Store the state by default
    case (state)
        STATE_IDLE:begin
            if (~FIFOA_empty) begin
                state_next   = STATE_FIFOAEn;
            end
        end
        STATE_FIFOAEn:begin
            state_next   = STATE_FIFOAEnOff;
        end

        STATE_FIFOAEnOff: begin
            state_next   = STATE_ReadFIFOA;
        end      

        STATE_ReadFIFOA:begin
            state_next   = STATE_TriggerWrite;
        end    

        STATE_TriggerWrite:begin
            state_next   = STATE_WriteFIFOB;
        end 

        STATE_WriteFIFOB:begin
            state_next   = STATE_IDLE;
        end 

        STATE_Occupy6: state_next   = STATE_IDLE;
        STATE_Occupy7: state_next   = STATE_IDLE;
    endcase
end
// ============================================================================= 
// Output logic             
// =============================================================================
always @(posedge CLK or negedge rst_n) begin
  if (~rst_n) begin
      FIFOA_ren        <= 1'b0;
      FIFOB_wen        <= 1'b0;
      FIFOB_IN         <= 32'd0;
      Triggered        <= 1'b0;
      addr_byte        <= 32'd0;
  end
  else begin
      case (state_next)
            STATE_IDLE:begin
               FIFOA_ren        <= 1'b0;
               FIFOB_wen        <= 1'b0;
               FIFOB_IN         <= 32'd0;
               addr_byte        <= 32'd0;
            end

            STATE_FIFOAEn:begin
                FIFOA_ren       <= 1'b1;
            end

            STATE_FIFOAEnOff: begin
                FIFOA_ren       <= 1'b0;
            end

            STATE_ReadFIFOA:begin
                addr_byte       <= FIFOA_OUT;
                FIFOB_IN        <= FIFOA_OUT;
            end

            STATE_WriteFIFOB:begin
                Triggered        <= 1'b1;
                FIFOB_wen        <= 1'b1;
            end 
      endcase
    end
end
endmodule