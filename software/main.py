"""
This is the top-level program.
"""
import logging
import os
import time
# import subprocess
import sys
import time

# Sanity check to make sure Python interpreter is with the compatible version with `OK` package
assert sys.version_info.major == 3 and sys.version_info.minor == 5, "OK FrontPanel only complies with Python 3.5"

from fpga_host.cmd_parser import CmdlineParser
from fpga_host.fpga_tester import FPGATester
from fpga_host.logger import setup_logger
from fpga_host.transmission_data import TransData
from fpga_host.data_gen import DataGen

DEBUG = True  # Knob to bypass the error w/o FPGA
w_path_full0W = 'DataOut/Weight/w_full0.txt'
w_path_fullFW = 'DataOut/Weight/w_fullF.txt'
w_path_randomW = 'DataOut/Weight/w_randomW.txt'

a_path_full0W = 'DataOut/Activation/a_full0.txt'
a_path_fullFW = 'DataOut/Activation/a_fullF.txt'
a_path_randomW = 'DataOut/Activation/a_randomW.txt'


o_path_full0W = 'DataOut/Output/o_full0.txt'
o_path_fullFW = 'DataOut/Output/o_fullF.txt'
o_path_randomW = 'DataOut/Output/o_randomW.txt'

# ----------------------------------------------------#
# Main Function
# ----------------------------------------------------#
def fpga_main():
    args = CmdlineParser().parse()
    # Config logger to have a pretty logging console
    setup_logger(FPGATester.__name__, args.log_level) 
    # Initialize FPGA tester and sanity check
    fpga_tester = FPGATester(args.fpga_bit, debug=DEBUG)
    if fpga_tester.device is None:
        sys.exit(1)
    run_host(fpga_tester)
# ----------------------------------------------------#
# Run the FPGA Host
# ----------------------------------------------------#
def run_host(fpga_tester):
    # Initialize Data control module
    setup_logger('CIM_Process', logging.INFO)
    trans = TransData(fpga_tester)
    trans.reset_host()                      # Reset FPGA host and logic

    trans.ind_write_reg(0x00,0x0003)        # Clear status signal by default
    trans.ind_read_reg(0x00)
    array32_ff = DataGen.array_fullff(32)
    act_num = int.from_bytes(array32_ff, 'big')
    #========================================================================
    # Run 64x4 times to increment activation from 0 to largest -- Full 0 Weight
    #========================================================================
    weights_data = DataGen.full_zeros(512)  # Generate data for testing
    act_data = DataGen.full_zeros(32)
    #------------------------------------------------#
    mac_onecycle(trans, weights_data, act_data, w_path_full0W, a_path_full0W, o_path_full0W)
    for _ in range (0,act_num, 15): 
        act_data = DataGen.array_increment(act_data, 32)
        mac_onecycle(trans, weights_data, act_data, w_path_full0W, a_path_full0W, o_path_full0W)
    #=========================================================================
    # Run 64x4 times to increment activation from 0 to largest -- Full F Weight
    #=========================================================================
    weights_data = DataGen.array_fullff(512)  # Generate data for testing
    act_data = DataGen.full_zeros(32)
    #------------------------------------------------#
    mac_onecycle(trans, weights_data, act_data, w_path_fullFW, a_path_fullFW, o_path_fullFW)
    for _ in range (0,act_num, 15): 
        act_data = DataGen.array_increment(act_data, 32)
        mac_onecycle(trans, weights_data, act_data, w_path_fullFW, a_path_fullFW, o_path_fullFW)
    #=========================================================================
    # Run 64x4 times to increment activation from 0 to largest -- Random Weight
    #=========================================================================
    weights_data = DataGen.array_random(512)  # Generate data for testing
    act_data = DataGen.full_zeros(32)
    #------------------------------------------------#
    mac_onecycle(trans, weights_data, act_data, w_path_randomW, a_path_randomW, o_path_randomW)
    for _ in range (0,act_num, 15): 
        act_data = DataGen.array_increment(act_data, 32)
        mac_onecycle(trans, weights_data, act_data, w_path_randomW, a_path_randomW, o_path_randomW)

# ----------------------------------------------------#
# Function for One cycle of MAC Operation 
# ----------------------------------------------------#
def mac_onecycle(trans, weights:bytearray, activations:bytearray, datapth_weight, datapath_act, datapath_out):
    trans.reset_host()
    trans.ind_write_reg(0x00,0x0003)         # Clear status signal by default

    trans.write_weights(weights)             # Write weights
    trans.write_activations(activations)     # Write activations
    time.sleep(1.2)
    # while trans.read_status(0x00) != 3:
    #     time.sleep(0.1)
    #     print('wait for finish writing data into chip...')
    trans.ind_read_reg(0x00)
    trans.askfor_outputs()                   # Finish writing
    time.sleep(0.1)
    outputs = trans.get_outputs()
    with open(datapath_out,'a') as out_object:
        out_object.write('\n')
        for num in outputs:
            out_object.write("{:02x}\t".format(num))
    with open(datapth_weight,'a') as w_object:
        w_object.write('\n')
        for num in weights:
            w_object.write("{:02x}\t".format(num))
    with open(datapath_act,'a') as a_object:
        a_object.write('\n')
        for num in activations:
            a_object.write("{:02x}\t".format(num))
# ----------------------------------------------------#
# ----------------------------------------------------#
if __name__ == "__main__":
    fpga_main()
