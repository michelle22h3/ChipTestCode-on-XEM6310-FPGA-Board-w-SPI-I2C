# This is a Modelsim simulation script.
# To use:
#  + Start Modelsim
#  + At the command-line, CD to the directory where this file is.
#  + Type: "do thisfilename.do"

# For more details on modelsim CLI, please refer to:
# https://www.microsemi.com/document-portal/doc_view/136364-modelsim-me-10-4c-command-reference-manual-for-libero-soc-v11-7

# Path variable setup
set SIM_LIB_PATH ./okSimLib
set RTL_SRC_PATH ../verilog

# Compile testbench and simulation model
vlog +incdir+$RTL_SRC_PATH+$SIM_LIB_PATH fpga_top_tb.v
vlog +incdir+$RTL_SRC_PATH+$SIM_LIB_PATH chip.v
vlog +incdir+$RTL_SRC_PATH+$SIM_LIB_PATH SPI_Slave.v

# Compile RTL source code
vlog +incdir+$RTL_SRC_PATH+$SIM_LIB_PATH $RTL_SRC_PATH/fpga_top.v
vlog +incdir+$RTL_SRC_PATH+$SIM_LIB_PATH $RTL_SRC_PATH/SPI_Master.v
vlog +incdir+$RTL_SRC_PATH+$SIM_LIB_PATH $RTL_SRC_PATH/spi_master_tx_ctrl.v
vlog +incdir+$RTL_SRC_PATH+$SIM_LIB_PATH $RTL_SRC_PATH/spi_master_rx_ctrl.v
vlog +incdir+$RTL_SRC_PATH+$SIM_LIB_PATH $RTL_SRC_PATH/main_ctrl.v

# Compile Xilinx ISE IP source code
vlog +incdir+$RTL_SRC_PATH $RTL_SRC_PATH/ise_ipcore/act_in_fifo/ActInFIFO.v
vlog +incdir+$RTL_SRC_PATH $RTL_SRC_PATH/ise_ipcore/weight_fifo/WeightFIFO.v
vlog +incdir+$RTL_SRC_PATH $RTL_SRC_PATH/ise_ipcore/act_out_fifo/ActOutFIFO.v
# vlog +incdir+$RTL_SRC_PATH $RTL_SRC_PATH/ise_ipcore/clk_div/ClkDiv.v

# Compile OK simulation model
vlog +incdir+$SIM_LIB_PATH $SIM_LIB_PATH/glbl.v
vlog +incdir+$SIM_LIB_PATH $SIM_LIB_PATH/okHost.v
vlog +incdir+$SIM_LIB_PATH $SIM_LIB_PATH/okWireIn.v
vlog +incdir+$SIM_LIB_PATH $SIM_LIB_PATH/okWireOut.v
vlog +incdir+$SIM_LIB_PATH $SIM_LIB_PATH/okWireOR.v
vlog +incdir+$SIM_LIB_PATH $SIM_LIB_PATH/okTriggerIn.v
vlog +incdir+$SIM_LIB_PATH $SIM_LIB_PATH/okTriggerOut.v
vlog +incdir+$SIM_LIB_PATH $SIM_LIB_PATH/okPipeIn.v
vlog +incdir+$SIM_LIB_PATH $SIM_LIB_PATH/okPipeOut.v
vlog +incdir+$SIM_LIB_PATH $SIM_LIB_PATH/okRegisterBridge.v

# Launch verilog simulation
vsim -t ps FPGATopTestbench -novopt +acc -L xilinxcorelib_ver -L unisims_ver -L unimacro_ver -L secureip 

#Setup waveforms
onerror {resume}
quietly WaveActivateNextPane {} 0

set WAVE_HEIGHT 40; # Variable configs wave height in pixels
set FONT_SIZE 15; # Variable configs font size in wave panel

# Chip SPI (activation & weight SPI interfaces)
add wave -divider {Chip SPI Interface}
add wave -height $WAVE_HEIGHT -format logic -radix binary /FPGATopTestbench/chip/CLK_100M
add wave -height $WAVE_HEIGHT -format logic -radix binary /FPGATopTestbench/chip/chip_start_mapw
add wave -height $WAVE_HEIGHT -format logic -radix binary /FPGATopTestbench/chip/chip_start_calc
add wave -height $WAVE_HEIGHT -format logic -radix binary /FPGATopTestbench/chip/A_SPI_CLK
add wave -height $WAVE_HEIGHT -format logic -radix binary /FPGATopTestbench/chip/A_SPI_CS_n
add wave -height $WAVE_HEIGHT -format logic -radix binary /FPGATopTestbench/chip/A_SPI_MOSI
add wave -height $WAVE_HEIGHT -format logic -radix binary /FPGATopTestbench/chip/A_SPI_MISO
add wave -height $WAVE_HEIGHT -format logic -radix binary /FPGATopTestbench/chip/W_SPI_CLK
add wave -height $WAVE_HEIGHT -format logic -radix binary /FPGATopTestbench/chip/W_SPI_CS_n
add wave -height $WAVE_HEIGHT -format logic -radix binary /FPGATopTestbench/chip/W_SPI_MOSI
add wave -height $WAVE_HEIGHT -format logic -radix binary /FPGATopTestbench/chip/state_reg

# FPGA controller (track the status of FPGA)
add wave -divider {FPGA Main Controller}
add wave -height $WAVE_HEIGHT -format logic -radix binary /FPGATopTestbench/UUT/main_ctrl/clk
add wave -height $WAVE_HEIGHT -format logic -radix binary /FPGATopTestbench/UUT/main_ctrl/rst
add wave -height $WAVE_HEIGHT -format Literal -radix hex /FPGATopTestbench/UUT/main_ctrl/state_reg
add wave -height $WAVE_HEIGHT -format Literal -radix hex /FPGATopTestbench/UUT/main_ctrl/led_state
add wave -height $WAVE_HEIGHT -format logic -radix binary /FPGATopTestbench/UUT/main_ctrl/weight_tx_data_valid
add wave -height $WAVE_HEIGHT -format Literal -radix unsigned /FPGATopTestbench/UUT/main_ctrl/weight_sent
add wave -height $WAVE_HEIGHT -format logic -radix binary /FPGATopTestbench/UUT/main_ctrl/act_in_tx_data_valid
add wave -height $WAVE_HEIGHT -format Literal -radix unsigned /FPGATopTestbench/UUT/main_ctrl/act_in_sent
add wave -height $WAVE_HEIGHT -format logic -radix binary /FPGATopTestbench/UUT/main_ctrl/act_out_rx_valid
add wave -height $WAVE_HEIGHT -format Literal -radix unsigned /FPGATopTestbench/UUT/main_ctrl/act_out_sent
add wave -height $WAVE_HEIGHT -format logic -radix binary /FPGATopTestbench/UUT/main_ctrl/start_mapw
add wave -height $WAVE_HEIGHT -format logic -radix binary /FPGATopTestbench/UUT/main_ctrl/start_calc
add wave -height $WAVE_HEIGHT -format logic -radix binary /FPGATopTestbench/UUT/main_ctrl/calc_done
add wave -height $WAVE_HEIGHT -format logic -radix binary /FPGATopTestbench/UUT/main_ctrl/act_out_rx_done

TreeUpdate [SetDefaultTree]
configure wave -namecolwidth 220
configure wave -valuecolwidth 70
configure wave -justifyvalue left
configure wave -signalnamewidth 1;  # Control the hierarchical name shown in wave panel
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -waveselectenable 1
configure wave -timelineunits ns
configure wave -font "Tahoma $FONT_SIZE"

run 500us

update
WaveRestoreZoom 0ns 500us