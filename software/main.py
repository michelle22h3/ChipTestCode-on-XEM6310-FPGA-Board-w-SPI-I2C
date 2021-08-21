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
    fpga_tester.itf_selection(1) # 0 means select I2C
    fpga_tester.led_cntl(0x2E)
    dataout = DataGen.full_zeros(fpga_tester.R_BYTES)
    
    # ----------------------------------------------------#  
    # Generate data and Writing Process
    write_dataA = DataGen.indir_write(0x10, 0x0733)
    print (write_dataA)
    fpga_tester.fifowtest(write_dataA)  # Write 16-bit data into \x10

    write_dataA = DataGen.indir_write(0x14, 0x77FF)
    print (write_dataA)
    fpga_tester.fifowtest(write_dataA)  # Write 16-bit data into \x14
    # ----------------------------------------------------#  
    # Generate data and Reading Process
    read_dataA = DataGen.indir_read(0x10)
    fpga_tester.fifowtest(read_dataA)  # Write command into FIFO
    print (fpga_tester.fifob_empty())
    fpga_tester.fifotest_read(dataout) # Read out data
    print(dataout[0], dataout[4])

    read_dataA = DataGen.indir_read(0x14)
    fpga_tester.fifowtest(read_dataA)  # Write command into FIFO
    print (fpga_tester.fifob_empty())
    fpga_tester.fifotest_read(dataout) # Read out data
    print(dataout[0], dataout[4])

    time.sleep(1)
    # print (fpga_tester.fifob_empty())
    # print("wait for fetching data")
    # while not fpga_tester.fifob_empty():
    #     fpga_tester.fifotest_read(dataout)
    #     print(dataout)
    #     print(dataout[0], dataout[4])
    # print (fpga_tester.fifob_empty())
    

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
