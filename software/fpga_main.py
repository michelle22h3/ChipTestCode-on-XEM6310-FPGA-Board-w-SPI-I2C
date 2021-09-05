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
class FpgaFun:
    def __init__(self):
        self.args = CmdlineParser().parse()
        self.fpga_tester = FPGATester(self.args.fpga_bit, debug=DEBUG)
        self.logger = logging.getLogger('CIM_Process')
        self.trans = TransData(self.fpga_tester)
    # ----------------------------------------------------#  
    # Initial and Reset FPGA Host and logic
    # ----------------------------------------------------#  
    def fpga_init(self):
        if self.fpga_tester.device is None:
            sys.exit(1)
    # Initialize Data control module
        self.trans.reset_host()
    # ----------------------------------------------------#
    # Run the FPGA Host
    # ----------------------------------------------------#
    def run_host(self):
        activationdata = DataGen.array_random(32)
        weightdata = DataGen.full_zeros(512)
        outdata = [1,1]
        self.access_reg()
        #power_measure(trans, activations=activationdata, weights=weightdata, outputs=outdata)
        #mac_onecycle(trans, activations=activationdata, weights=weightdata, outputs=outdata)
        self.cim_processing(activations=activationdata, weights=weightdata, outputs=outdata)
        print(outdata)
    # ----------------------------------------------------#
    # Function for One cycle of MAC Operation 
    # ----------------------------------------------------#
    def access_reg(self):
        self.trans.reset_host()
        self.trans.ind_write_reg(0x14,0x0070)        # Set Start Bit
        self.trans.ind_write_reg(0x00,0x0003) 
        self.trans.ind_read_reg(0x00)         
        self.trans.ind_read_reg(0x14) 

    def cim_processing(self, activations:bytearray, weights:bytearray, outputs:list):
        self.trans.reset_host() 
        self.trans.ind_write_reg(0x00,0x0003)         # Clear status
        self.trans.ind_write_reg(0x2C,0x0003)         # Enable Writing weights
        self.trans.write_weights(weights)             # Write weights
        self.trans.write_activations(activations)     # Write activations
        time.sleep(1.5)
        #trans.mac_assert_finish() 
        self.trans.emptyfifo()
        self.trans.askfor_outputs()                  # Finish writing
        time.sleep(0.1)                
        outputs_bytes = self.trans.get_outputs()
        self.trans.decode_out(outputs_bytes, outputs)


    def power_measure(self,activations:bytearray, weights:bytearray, outputs:list):
        self.trans.reset_host() 
        self.trans.ind_write_reg(0x00,0x0003)         # Clear status
        self.trans.ind_write_reg(0x2C,0x0003)         # Enable Writing weights
        self.trans.write_weights(weights)             # Write weights
        self.trans.write_activations(activations)     # Write activations
        time.sleep(1.5)
        #trans.mac_assert_finish() 
        self.trans.ind_read_reg(0x00)
        for _ in range(100):           
            self.trans.ind_write_reg(0x24,0x0002)  


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
    # Config logger to have a pretty logging console
    setup_logger('CIM_Process', logging.INFO)
    fpga_main = FpgaFun()
    fpga_main.fpga_init()
    fpga_main.run_host()
