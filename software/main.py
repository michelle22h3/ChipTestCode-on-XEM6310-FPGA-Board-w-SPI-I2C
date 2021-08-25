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


def main():
    # ----------------------------------------------------#
    args = CmdlineParser().parse()
    # Config logger to have a pretty logging console
    setup_logger(FPGATester.__name__, args.log_level) 
    # Initialize FPGA tester and sanity check
    fpga_tester = FPGATester(args.fpga_bit, debug=DEBUG)
    if fpga_tester.device is None:
        sys.exit(1)
    # Initialize Data control module
    setup_logger('CIM_Process', logging.DEBUG)
    trans = TransData(fpga_tester)
    # Reset FPGA host and logic
    trans.reset_host()
    trans.ind_write_reg(0x00,0x0003) # Clear status signal by default
    # ----------------------------------------------------#
    # trans.ind_write_reg(0x00,0x0000)
    # trans.ind_write_reg(0x14,0x77FF)
    # trans.ind_write_reg(0x24,0x4)
    # trans.ind_write_reg(0x28,0xF)
    # trans.ind_write_reg(0x2C,0x3)
  
    # trans.ind_read_reg(0x10)
    # trans.ind_read_reg(0x14)
    # trans.ind_read_reg(0x24)
    # trans.ind_read_reg(0x28)
    # trans.ind_read_reg(0x2C)

    
    trans.ind_read_reg(0x00)

    weights_data = DataGen.array_random(512)
    act_data = DataGen.array_random(32)
    outputdata = DataGen.full_zeros(80)
    trans.ind_read_reg(0x00)

    trans.write_weights(weights_data)
    trans.write_activations(act_data)
    time.sleep(1)
    trans.ind_read_reg(0x00)
    trans.askfor_outputs()
    time.sleep(1)
    trans.get_outputs(outputdata)



if __name__ == "__main__":
    main()
