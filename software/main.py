"""
This is the top-level program.
"""
import logging
import time
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

path_out = 'DataOut/ReceivedOutput.txt'
path_outtheory = 'DataOut/TheoryOutput.txt'

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
    # trans.ind_write_reg(0x00,0x0003)        # Clear status signal by default
    trans.ind_read_reg(0x14)
    trans.ind_read_reg(0x00) 

    # trans.ind_write_reg(0x14,0x0060)        # Set Start Bit

    activationdata = DataGen.array_random(32)
    weightdata = DataGen.full_zeros(512)
    outdata = []
    mac_onecycle(trans, activations=activationdata, weights=weightdata, outputs=outdata)
# ----------------------------------------------------#
# Function for One cycle of MAC Operation 
# ----------------------------------------------------#
def mac_onecycle(trans, activations:bytearray, weights:bytearray, outputs:list):
    trans.reset_host() 
    trans.ind_write_reg(0x00,0x0003)  
    trans.write_weights(weights)             # Write weights
    trans.write_activations(activations)     # Write activations
    time.sleep(1.5)
    trans.mac_assert_finish() 
    trans.askfor_outputs()                  # Finish writing
    time.sleep(0.1)                
    outputs_bytes = trans.get_outputs()
    outputs = trans.decode_out(outputs_bytes)
    print(outputs)
    outputs_theory = trans.output_theory(activations, weights)
    print(outputs_theory)
    with open(path_out,'a') as filea:
        filea.write("%s\n" % outputs)
    with open(path_outtheory,'a') as fileb:
        fileb.write("%s\n" % outputs_theory)
# ----------------------------------------------------#
# ----------------------------------------------------#
if __name__ == "__main__":
    fpga_main()
