"""
This is the top-level program.
"""
import logging
import os
# import subprocess
import sys
import time

# Sanity check to make sure Python interpreter is with the compatible version with `OK` package
assert sys.version_info.major == 3 and sys.version_info.minor == 5, "OK FrontPanel only complies with Python 3.5"

from fpga_host.cmd_parser import CmdlineParser
from fpga_host.fpga_tester import FPGATester
from fpga_host.logger import setup_logger
from fpga_host.transmission_data import TransData

DEBUG = True  # Knob to bypass the error w/o FPGA


def main():
    args = CmdlineParser().parse()
    # Config logger to have a pretty logging console
    setup_logger(FPGATester.__name__, args.log_level) 

    # Initialize FPGA tester and sanity check
    fpga_tester = FPGATester(args.fpga_bit, debug=DEBUG)
    if fpga_tester.device is None:
        sys.exit(1)
    # Reset FPGA host and logic
    setup_logger('CIM_Process', logging.DEBUG)
    trans = TransData(fpga_tester)
    trans.reset_host()
    # trans.test_indirwr()
    trans.ind_write_reg(0x10,0x0733)
    trans.ind_write_reg(0x14,0x77FF)
    trans.ind_write_reg(0x24,0x4)
    trans.ind_write_reg(0x28,0xF)
    trans.ind_write_reg(0x2C,0x3)
    trans.ind_write_reg(0x2C,0x3)
    trans.ind_write_reg(0x30,0xDD)
    trans.ind_write_reg(0x34,0xCC)

    trans.ind_read_reg(0x10)
    trans.ind_read_reg(0x14)
    

    # trans.write_weights(0xFFFFFFEEDDCCBBAABBCCDDEEFF998877665544332211)
    # trans.write_activations(0x77665544332211542675)
    # trans.askfor_outputs()
    # outputdata = bytearray(80)
    # trans.get_outputs(outputdata)
    # print(outputdata)


if __name__ == "__main__":
    main()
