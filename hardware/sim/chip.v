// -----------------------------------------------------------------------------
// This module emulates the behavior of chip design
// -----------------------------------------------------------------------------

module Chip (input wire CLK_100M,        // 100MHz clock from FPGA to IC
             input wire rst_n,           // Chip reset from FPGA to IC (active low)
             input wire chip_start_mapw, // 2-cycle trigger signal indicating IC start the weight mapping
             input wire chip_start_calc, // 2-cycle indicator to start the calculation
             input wire A_SPI_CLK,       // Activation SPI clock
             input wire A_SPI_MOSI,      // Activation SPI data from master to slave
             input wire A_SPI_CS_n,      // Activation SPI chip select (active low)
             output wire A_SPI_MISO,     // Activation SPI data from slave to master
             input wire W_SPI_CLK,       // Weight SPI clock
             input wire W_SPI_MOSI,      // Weight SPI data from master to slave
             input wire W_SPI_CS_n);     // Weight SPI chip select (active low)
    
    // Clock cycles for chip to finish the calculation
    localparam COMP_CYCLES = 1000;
    
    // -----------------------------------------------------------------------------
    // Internal connections declaration
    // -----------------------------------------------------------------------------
    // Received input activations data
    wire [7:0] act_in_data;
    wire act_in_data_valid;
    // Transmitted output activations data
    reg [7:0] act_out_data;
    reg act_out_data_valid;
    // Received weight data
    wire [7:0] weight_data;
    wire weight_data_valid;
    
    // Store the received input activation and weights
    reg [7:0] act_in_rx [63:0]; // 64B
    reg [5:0] act_in_idx; // Track index for received act in index
    reg [7:0] weight_rx [511:0]; // 512B
    reg [8:0] weight_idx; // Track index for received weight index
    // Store the calculated results (for simulation purpose)
    reg [7:0] act_out_results [63:0]; // 64B
    
    integer i;
    
    // -----------------------------------------------------------------------------
    // Instantiation of activation SPI slave
    // -----------------------------------------------------------------------------
    SPI_Slave #(.SPI_MODE(0)) act_spi_slave
    (
    // Control/Data Signals,
    .i_Rst_L        (rst_n),                // FPGA Reset
    .i_Clk          (CLK_100M),             // FPGA Clock
    .o_RX_DV        (act_in_data_valid),    // Data Valid pulse (1 clock cycle)
    .o_RX_Byte      (act_in_data),          // Byte received on MOSI
    .i_TX_DV        (act_out_data_valid),   // Data Valid pulse to register i_TX_Byte
    .i_TX_Byte      (act_out_data),         // Byte to serialize to MISO.
    
    // SPI Interface
    .i_SPI_Clk      (A_SPI_CLK),
    .o_SPI_MISO     (A_SPI_MISO),
    .i_SPI_MOSI     (A_SPI_MOSI),
    .i_SPI_CS_n     (A_SPI_CS_n)
    );
    
    // -----------------------------------------------------------------------------
    // Instantiation of weight SPI slave
    // -----------------------------------------------------------------------------
    SPI_Slave #(.SPI_MODE(0)) weight_spi_slave
    (
    // Control/Data Signals,
    .i_Rst_L        (rst_n),                // FPGA Reset
    .i_Clk          (CLK_100M),             // FPGA Clock
    .o_RX_DV        (weight_data_valid),    // Data Valid pulse (1 clock cycle)
    .o_RX_Byte      (weight_data),          // Byte received on MOSI
    .i_TX_DV        (1'b0),                 // Data Valid pulse to register i_TX_Byte
    .i_TX_Byte      (8'b0),                 // Byte to serialize to MISO.
    
    // SPI Interface
    .i_SPI_Clk      (W_SPI_CLK),
    .o_SPI_MISO     (/* floating */),
    .i_SPI_MOSI     (W_SPI_MOSI),
    .i_SPI_CS_n     (W_SPI_CS_n)
    );
    
    // -----------------------------------------------------------------------------
    // Monitor the received data and print to console
    // -----------------------------------------------------------------------------
    always @ (posedge CLK_100M) begin
        if (~rst_n) begin
            act_in_idx <= 6'b0;
            weight_idx <= 9'b0;
        end
        else begin
            if (act_in_data_valid) begin
                $display("[@time = %t]: chip receives input act: %d", $time, act_in_data);
                act_in_idx            <= act_in_idx + 1;
                act_in_rx[act_in_idx] <= act_in_data;
            end
            
            if (weight_data_valid) begin
                $display("[@time = %t]: chip receives weight: %d", $time, weight_data);
                weight_idx            <= weight_idx + 1;
                weight_rx[weight_idx] <= weight_data;
            end
        end
    end
    
    // ------------------------------------------------------------------------------
    // Monitor the start processing indicator
    // ------------------------------------------------------------------------------
    always @(posedge CLK_100M) begin
        if (rst_n && chip_start_calc) begin
            $display("[@time = %t]: chip starts to calculate", $time);
        end
    end
    
    // -------------------------------------------------------------------------------
    // Prepare the data to be sent out by slave
    // -------------------------------------------------------------------------------
    localparam STATE_IDLE = 2'd0;
    localparam STATE_MAP  = 2'd1;
    localparam STATE_COMP = 2'd2;
    localparam STATE_SPI  = 2'd3;
    
    reg [$clog2(COMP_CYCLES)-1:0] comp_cycles;
    reg [1:0] state_reg;
    reg [6:0] act_out_idx; // Record TX act output index
    always @ (posedge CLK_100M) begin
        if (~rst_n) begin
            state_reg          <= STATE_IDLE;
            comp_cycles        <= 0;
            act_out_idx        <= 0;
            act_out_data_valid <= 1'b0;
            act_out_data       <= 8'b0;
            for (i = 0; i < 64; i = i + 1) begin
                act_out_results[i] <= 0;
            end
        end else begin
            case(state_reg)
                STATE_IDLE: begin
                    if (chip_start_mapw) begin
                        state_reg   <= STATE_MAP;
                    end
                end

                STATE_MAP: begin
                    if (chip_start_calc) begin
                        state_reg   <= STATE_COMP;
                        comp_cycles <= 0;
                    end
                end
                
                STATE_COMP: begin
                    comp_cycles <= comp_cycles + 1;
                    if (comp_cycles == COMP_CYCLES-1) begin
                        state_reg <= STATE_SPI;
                    end
                    // Simply add weight[63:0] + act_in[63:0] during computation state
                    for (i = 0; i < 64; i = i + 1) begin
                        act_out_results[i] <= act_in_rx[i] + weight_rx[i];
                    end
                end
                STATE_SPI: begin
                    act_out_data_valid <= 1'b1;
                    act_out_data       <= act_out_results[act_out_idx];
                    if (act_in_data_valid) begin
                        act_out_idx <= act_out_idx + 1; // Transmit the next act out to master
                    end
                    
                    if (act_out_idx == 64) begin
                        state_reg          <= STATE_IDLE;
                        comp_cycles        <= 0;
                        act_out_idx        <= 0;
                        act_out_data_valid <= 1'b0;
                        act_out_data       <= 8'b0;
                    end
                end
            endcase
        end
    end
    
endmodule
