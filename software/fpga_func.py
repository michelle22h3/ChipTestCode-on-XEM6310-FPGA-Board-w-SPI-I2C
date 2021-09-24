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

path_out = 'DataOut/ReceivedOut0916.txt'
path_outtheory = 'DataOut/TheoryOut0916.txt'

# ----------------------------------------------------#
# Main Function
# ----------------------------------------------------#
class FpgaFunc:
    def __init__(self):
        self.args = CmdlineParser().parse()
        self.fpga_tester = FPGATester(self.args.fpga_bit, debug=DEBUG)
        self.logger = logging.getLogger('CIM_Process')
        self.trans = TransData(self.fpga_tester)
    # ----------------------------------------------------#  
    # Initial and Reset FPGA Host and logic
    # ----------------------------------------------------#  
    def fpga_init(self):
        # Initialize and configure FPGA
        self.fpga_tester.initialize_device()
        # Reset and update all the signals 
        self.trans.reset_host()
    # ----------------------------------------------------#
    # Run the FPGA Host
    # ----------------------------------------------------#
    def run_host(self):
        activationdata = DataGen.full_zeros(32)
        weightdata = DataGen.full_zeros(512)
        outdata = []
        self.access_reg()
        self.cim_processing(activations=activationdata, weights=weightdata, outputs=outdata)
        for _ in range (15):
            outdata = []
            DataGen.array_increment_each(activationdata)
            self.cim_processing(activations=activationdata, weights=weightdata, outputs=outdata)
    # ----------------------------------------------------#
    # Function for One cycle of MAC Operation 
    # ----------------------------------------------------#
    def access_reg(self):
        self.trans.reset_host()
        # Prepare the bytearray to be written into FIFOA
        w_to_reg=bytearray(0)
        self.trans.wdata_fifoa_append(0x14,0x0090,w_to_reg)  # Set Start Bit to 9
        self.trans.wdata_fifoa_append(0x00,0x0003,w_to_reg)  # Clear status of Chip
        self.trans.wdata_fifoa_append(0x2C,0x0003,w_to_reg)  # Enable weight and actvation writing
        self.trans.wdata_fifoa_append(0x00,0x0003,w_to_reg) 
        self.trans.rdata_fifob_append(0x00,w_to_reg)         # 2x32bit in FIFOB
        self.trans.rdata_fifob_append(0x10,w_to_reg)   
        self.trans.rdata_fifob_append(0x14,w_to_reg) 
        self.trans.rdata_fifob_append(0x2C,w_to_reg)  
        self.trans.pipe_data_in(w_to_reg)
        self.trans.pipe_data_out(num=4) # Number of regs to be read, num must be even numbers
    # ----------------------------------------------------#

    def cim_processing(self, activations:bytearray, weights:bytearray, outputs:list):
        self.trans.update_wires()

        self.trans.write_weights(weights)             # Write weights
        self.trans.write_activations(activations)     # Write activations
        time.sleep(1.2)
        self.trans.mac_assert_finish() 
        time.sleep(0.1)
        outdata_re = self.trans.get_640b_out()
        self.trans.decode_out(outdata_re, outputs)
        print(outputs)
        outputs_theory = self.trans.output_theory(activations, weights)
        print('Theory: {} '.format(outputs_theory))
        with open(path_out,'a') as filea:
            filea.write("%s\n" % outputs)
        with open(path_outtheory,'a') as fileb:
            fileb.write("%s\n" % outputs_theory)
    # ----------------------------------------------------#

    def mac_onecycle(self, activations:bytearray, weights:bytearray, outputs:list):
        self.trans.reset_host() 
        self.trans.ind_write_reg(0x00,0x0003)         # Clear status
        self.trans.ind_write_reg(0x2C,0x0003)         # Enable Writing weights
        self.trans.write_weights(weights)             # Write weights
        self.trans.write_activations(activations)     # Write activations
        time.sleep(1.5)
        self.trans.mac_assert_finish() 
        self.trans.emptyfifo()
        self.trans.askfor_outputs()                  # Finish writing
        time.sleep(0.1)                
        outputs_bytes = self.trans.get_outputs()
        outputs = self.trans.decode_out(outputs_bytes)
        print(outputs)
        outputs_theory = self.trans.output_theory(activations, weights)
        print(outputs_theory)
        # with open(path_out,'a') as filea:
        #     filea.write("%s\n" % outputs)
        # with open(path_outtheory,'a') as fileb:
        #     fileb.write("%s\n" % outputs_theory)
# ----------------------------------------------------#
# ----------------------------------------------------#
if __name__ == "__main__":
    # (1) Config logger to have a pretty logging console
    setup_logger('CIM_Process', logging.INFO)
    # (2) Instantiate the main control class
    fpga_main = FpgaFunc()
    # FPGA: Initialization
    fpga_main.fpga_init()
    fpga_main.run_host()
