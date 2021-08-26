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
data_path_full0W = 'DataOut/WeightFullZero0826.txt'
data_path_fullFW = 'DataOut/WeightFullFF0826.txt'
# ----------------------------------------------------#
# Main Function
# ----------------------------------------------------#
def main():
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
    #------------------------------------------------#
    weights_data = DataGen.full_zeros(512)  # Generate data for testing
    act_data = DataGen.full_zeros(32)
    output_data = DataGen.full_zeros(80)
    #------------------------------------------------#
    # array32_ff = DataGen.array_fullff(32)
    # act_num = int.from_bytes(array32_ff, 'big')
    act_num = 1
    #==========================================================
    # Run 64x4 times to increment activation from 0 to largest
    #==========================================================
    mac_onecycle(trans, weights_data, act_data, output_data, data_path_full0W)
    
    for i in range (0,act_num): 
        mac_onecycle(trans, weights_data, act_data, output_data, data_path_full0W)
    #------------------------------------------------#
    weights_data = DataGen.array_fullff(512)  # Generate data for testing
    act_data = DataGen.full_zeros(32)
    output_data = DataGen.full_zeros(80)
    #==========================================================
    # Run 64x4 times to increment activation from 0 to largest
    #==========================================================
    mac_onecycle(trans, weights_data, act_data, output_data, data_path_fullFW)
    
    for i in range (0,act_num): 
        mac_onecycle(trans, weights_data, act_data, output_data, data_path_fullFW)

# ----------------------------------------------------#
# Function for One cycle of MAC Operation 
# ----------------------------------------------------#
def mac_onecycle(trans, weights:bytearray, activations:bytearray, outputs:bytearray, data_path):
    
    trans.ind_write_reg(0x00,0x0003)         # Clear status signal by default
    trans.ind_read_reg(0x00)                 # Start Writing Weights and Activations
    trans.write_weights(weights)             # Write weights
    trans.write_activations(activations)     # Write activations
    # while not trans.read_status(0x00):
    #     time.sleep(0.1)
    #     print('wait for finish writing data into chip...')
    trans.askfor_outputs()                   # Finish writing
    time.sleep(0.1)
    trans.get_outputs(outputs)
    with open(data_path,'a') as file_object:
        for num in outputs:
            file_object.write("{:02x}\t".format(num)) 

# ----------------------------------------------------#
# ----------------------------------------------------#
if __name__ == "__main__":
    main()
