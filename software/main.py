"""
This is the top-level program.
"""

import os
# import subprocess
import sys
import time

# Sanity check to make sure Python interpreter is with the compatible version with `OK` package
assert sys.version_info.major == 3 and sys.version_info.minor == 5, "OK FrontPanel only complies with Python 3.5"

from fpga_host.cmd_parser import CmdlineParser
from fpga_host.data_gen import DataGen
from fpga_host.fpga_tester import FPGATester
from fpga_host.logger import setup_logger

DEBUG = True  # Knob to bypass the error w/o FPGA


def run_host(fpga_tester, args):
    """Program to run the host python program."""
    # Generate synthetic data for test (random here)
    # to_be_sent = [0, 0xAB, 0xCD, 0xEF]
    # data_waddr = bytearray(to_be_sent)
    weight_data = DataGen.random_array(fpga_tester.W_BYTES)
    
    weight_data_out = DataGen.full_zeros(fpga_tester.R_BYTES)
    # Main procedure for FPGA
    fpga_tester.reset()
    fpga_tester.config_spimaster()
    
    fpga_tester.itf_selection(1) # 0 means select I2C
    print (fpga_tester.fifob_empty())
    fpga_tester.led_cntl(0x3E)
    # Write 1 byte data of itf_reg
    print(weight_data)
    fpga_tester.fifotest(weight_data)
    # Write 1 byte data of itf_reg
    time.sleep(1)
    print (fpga_tester.fifob_empty())
    print("wait for fetching data")
    while not fpga_tester.fifob_empty():
        fpga_tester.fifotest_read(weight_data_out)
        print(weight_data_out)
    # onebyte_raddr, onebyte_rdata = fpga_tester.fpga_load_out()
    print (fpga_tester.fifob_empty())
    
    # print(onebyte_rdata)

def main():
    args = CmdlineParser().parse()
    # Config logger to have a pretty logging console
    setup_logger(FPGATester.__name__, args.log_level) 

    # Initialize FPGA tester and sanity check
    fpga_tester = FPGATester(args.fpga_bit, debug=DEBUG)
    if fpga_tester.device is None:
        sys.exit(1)

    run_host(fpga_tester, args)


if __name__ == "__main__":
    main()
