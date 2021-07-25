// -----------------------------------------------------------------------------
// Main controller for FPGA to track the progress of data RX and TX
// -----------------------------------------------------------------------------

module MainCtrl #(parameter DRAIN_TX_CYCLE = 30,   // Number of cycles for IC receive all tx data
                  parameter CHIP_MAP_CYCLE = 1000,
                  parameter CHIP_COMP_CYCLE = 1000) // Number of cycles for IC finishes calculation
                 (input wire clk,                  // System clock
                  input wire rst,                  // System reset
                  input wire weight_tx_data_valid, // Weight TX valid (1B sent to slave)
                  input wire act_in_tx_data_valid, // Input activation TX valid (1B sent to slave)
                  input wire act_out_rx_valid,     // Output activation RX valid (1B received by master)
                  output wire act_out_rx_stage,    // Flag for receiving activation stage
                  output wire act_spi_slave_cs,    // Chip select of activation SPI slave interface
                  output wire weight_spi_slave_cs, // Chip select of weight SPI slave interface
                  output reg start_mapw,           // 2-cycle trigger signal indicating IC start the weight mapping
                  output reg start_calc,           // 2-cycle trigger to tell IC start calculation
                  output reg calc_done,            // 1-cycle trigger to tell host IC finishes calculation
                  output reg [3:0] led_state,      // Indicator of current state of main control logic
                  output reg act_out_rx_done);     // 1-cycle trigger to tell host IC sent out all calculated data
    
    `include "config.vh"
    
    // Handy constants for counters (extra bit to avoid potential MSB overflow)
    parameter ACT_IN_WIDTH   = $clog2(`ACT_IN_BYTES) + 1;
    parameter WEIGHT_WIDTH   = $clog2(`WEIGHT_BYTES) + 1;
    parameter ACT_OUT_WIDTH  = $clog2(`ACT_OUT_BYTES) + 1;
    parameter DRAIN_TX_WIDTH = $clog2(DRAIN_TX_CYCLE);
    parameter MAP_WIDTH      = $clog2(CHIP_MAP_CYCLE);
    parameter COMP_WIDTH     = $clog2(CHIP_COMP_CYCLE);
    
    // -------------------
    // FSM state encoding
    // -------------------
    localparam STATE_IDLE  = 3'd0; // Initial idle state
    localparam STATE_TX    = 3'd1; // State for transmitting data
    localparam STATE_DRAIN = 3'd2; // State to drain the transmitted data from FPGA to chip
    localparam STATE_MAP   = 3'd3; // State to map weight on SRAM Array
    localparam STATE_COMP  = 3'd4; // State for chip to computation
    localparam STATE_RX    = 3'd5; // State for FPGA to receive the calculated result from IC
    
    // --------------------
    // FSM state registers
    // --------------------
    reg [2:0] state_reg; // FSM state register
    
    // Counters to track the status
    reg [ACT_IN_WIDTH-1:0]      act_in_sent;    // Number of bytes of input activation sent
    reg [WEIGHT_WIDTH-1:0]      weight_sent;    // Number of bytes of weight sent
    reg [ACT_OUT_WIDTH-1:0]     act_out_sent;   // Number of bytes of output activation sent
    reg [DRAIN_TX_WIDTH-1:0]    drain_cycle;    // Record the number of cycles to drain the data
    reg [MAP_WIDTH-1:0]         map_cycle;      // Record the number of cycles to map the weight
    reg [COMP_WIDTH-1:0]        comp_cycle;     // Record the number of cycles to finish computation
    
    // -----------------------------------
    // FSM next logic and state registers
    // -----------------------------------
    always @(posedge clk) begin
        if (rst) begin
            state_reg       <= STATE_IDLE;
            act_in_sent     <= {ACT_IN_WIDTH{1'b0}};
            weight_sent     <= {WEIGHT_WIDTH{1'b0}};
            act_out_sent    <= {ACT_OUT_WIDTH{1'b0}};
            drain_cycle     <= {DRAIN_TX_WIDTH{1'b0}};
            map_cycle       <= {MAP_WIDTH{1'b0}};
            comp_cycle      <= {COMP_WIDTH{1'b0}};
            start_mapw      <= 1'b0;
            start_calc      <= 1'b0;
            calc_done       <= 1'b0;
            led_state       <= 4'b0000;
            act_out_rx_done <= 1'b0;
        end
        else begin
            case (state_reg)
                STATE_IDLE: begin
                    act_out_rx_done <= 1'b0;
                    if (act_in_tx_data_valid || weight_tx_data_valid) begin
                        state_reg <= STATE_TX;
                    end
                    
                    if (act_in_tx_data_valid) begin
                        act_in_sent <= act_in_sent + 1; //Counting on the 1st byte of data
                    end
                    
                    if (weight_tx_data_valid) begin
                        weight_sent <= weight_sent + 1;
                    end
                    
                    calc_done <= 1'b0;
                end
                
                STATE_TX: begin
                    if (act_in_sent == `ACT_IN_BYTES && weight_sent == `WEIGHT_BYTES) begin
                        // We have sent all the input activations and weights for 1 layer
                        // Transfer to receiving state to wait for the calculated output activations
                        state_reg <= STATE_DRAIN;
                    end
                    
                    if (act_in_tx_data_valid) begin
                        act_in_sent <= act_in_sent + 1;
                    end
                    
                    if (weight_tx_data_valid) begin
                        weight_sent <= weight_sent + 1;
                    end
                end
                
                STATE_DRAIN: begin
                    drain_cycle <= drain_cycle + 1;
                    if (drain_cycle == DRAIN_TX_CYCLE - 2) begin
                        start_mapw <= 1'b1;
                    end

                    if (drain_cycle == DRAIN_TX_CYCLE - 1) begin
                        state_reg  <= STATE_MAP;
                        led_state <= 4'b0001;
                    end
                end
                
                STATE_MAP: begin
                    start_mapw <= 1'b0;
                    map_cycle  <= map_cycle + 1;
                    if (map_cycle == CHIP_MAP_CYCLE - 2) begin
                        start_calc <= 1'b1;
                    end

                    if (map_cycle == CHIP_MAP_CYCLE - 1) begin
                        state_reg <= STATE_COMP;
                        led_state <= 4'b0011;
                    end
                end


                STATE_COMP: begin
                    start_calc <= 1'b0;
                    comp_cycle <= comp_cycle + 1;
                    if (comp_cycle == CHIP_COMP_CYCLE - 1) begin
                        calc_done <= 1'b1; // 1-cycle tick to indicate chip finish calculation
                        state_reg <= STATE_RX;
                        led_state <= 4'b0111;
                    end
                end
                
                STATE_RX: begin
                    calc_done <= 1'b0;
                    if (act_out_sent == `ACT_OUT_BYTES) begin
                        // We have received all the calculated output activations, transfer to initial idle state
                        state_reg <= STATE_IDLE;
                        // Reset all counters
                        act_in_sent     <= {ACT_IN_WIDTH{1'b0}};
                        weight_sent     <= {WEIGHT_WIDTH{1'b0}};
                        act_out_sent    <= {ACT_OUT_WIDTH{1'b0}};
                        drain_cycle     <= {DRAIN_TX_WIDTH{1'b0}};
                        map_cycle       <= {MAP_WIDTH{1'b0}};
                        comp_cycle      <= {COMP_WIDTH{1'b0}};
                        act_out_rx_done <= 1'b1; // Assert 1 cycle since all activation out has been received
                        led_state       <= 4'b1111; // Finished all the logic state in one cycle
                    end
                    
                    if (act_out_rx_valid) begin
                        act_out_sent <= act_out_sent + 1;
                    end
                end
            endcase
        end
    end
    
    // -----------------
    // FSM output logic
    // -----------------
    assign act_out_rx_stage    = (state_reg == STATE_RX);
    assign weight_spi_slave_cs = (state_reg == STATE_TX) | (state_reg == STATE_DRAIN);
    assign act_spi_slave_cs    = (state_reg == STATE_RX) | (state_reg == STATE_TX) | (state_reg == STATE_DRAIN);
    
endmodule
