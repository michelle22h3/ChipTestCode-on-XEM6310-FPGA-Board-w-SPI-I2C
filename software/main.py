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
    # ----------------------------------------------------#  
    # Main procedure for FPGA
    fpga_tester.reset()
    fpga_tester.config_spimaster()
    fpga_tester.itf_selection(0) # 0 means select I2C
    fpga_tester.led_cntl(0x2E)
    dataout = DataGen.full_zeros(fpga_tester.R_BYTES)
    
    # ----------------------------------------------------#  
    # Generate synthetic data for test (random here)
    write_dataA = DataGen.test_write()
    write_dataB = DataGen.test_write()
    write_dataC = DataGen.test_write()
    write_dataD = DataGen.test_write()
    write_dataA.extend(write_dataB)
    write_dataA.extend(write_dataC)
    write_dataA.extend(write_dataD)

    print (write_dataA)
 
    # Write
    fpga_tester.fifotest(write_dataA)

    read_dataA = DataGen.test_read()
    fpga_tester.fifotest(read_dataA)

    # Write
    time.sleep(1)
    print (fpga_tester.fifob_empty())
    print("wait for fetching data")
    while not fpga_tester.fifob_empty():
        fpga_tester.fifotest_read(dataout)
        print(dataout)
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
