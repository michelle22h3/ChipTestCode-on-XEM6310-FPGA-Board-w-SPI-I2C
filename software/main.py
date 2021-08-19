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
    onebyte_waddr = int(0x03)
    onebyte_wdata = int(0xAB)

    # Main procedure for FPGA
    fpga_tester.reset()
    time.sleep(1)
    fpga_tester.config_spimaster()

    fpga_tester.itf_selection(1) # 0 means select I2C
    print (fpga_tester.fifob_empty())
    fpga_tester.led_cntl(0x3E)
    time.sleep(5)
    fpga_tester.led_cntl(0x2E)
    # Write 1 byte data of itf_reg
    fpga_tester.fpga_write_byte(onebyte_waddr, onebyte_wdata)
    # Write 1 byte data of itf_reg
    fpga_tester.fpga_read_byte(onebyte_waddr)
    
    time.sleep(1)
    print("wait for fetching data")
    print (fpga_tester.fifob_empty())
    onebyte_raddr, onebyte_rdata = fpga_tester.fpga_load_out()
    print(onebyte_raddr)
    print(onebyte_rdata)

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
