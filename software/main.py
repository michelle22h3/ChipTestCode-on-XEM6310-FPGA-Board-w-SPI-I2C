"""
This is the top-level program.
"""

import os
import subprocess
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
    onebyte_waddr = 0x02
    onebyte_wdata = 0xAB

    # Main procedure for FPGA
    fpga_tester.reset()
    fpga_tester.itf_selection(0) # 0 means select I2C

    # Send activation input and initiate output data transfer state
    fpga_tester.send_one_byte(onebyte_waddr, onebyte_wdata)

    Ready_to_read = False
    while not Ready_to_read:
        fpga_tester.logger.info("Sleep 1 second to wait fifo_b not empty")
        time.sleep(1)
        Ready_to_read = fpga_tester.fifob_not_empty()
    Ready_to_read = False

    # Read the calculated data
    onebyte_raddr, onebyte_rdata = fpga_tester.receive_one_byte()
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
