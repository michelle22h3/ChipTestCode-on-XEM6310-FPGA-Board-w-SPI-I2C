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

path_out = 'DataOut/ReceivedOut.txt'
path_out_scale = 'DataOut/ReceivedOut_wScale.txt'

path_outtheory = 'DataOut/TheoryOut.txt'
path_wei = 'DataOut/Weight.txt'

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
        # Reset Chip
        self.trans.reset_chip()
    # ----------------------------------------------------#
    # Run the FPGA Host
    # ----------------------------------------------------#
    def run_host(self): 
        """Here we call the following fuctions to do data tx and computing"""
        self.access_reg()
        # for _ in range(10):
        #     self.mac_offset_measure()
        # self.offset_compen()
        # self.edges()
        # self.plus_one()
        self.act_shift_append()

    def mac_offset_measure(self):
        """Measure the offset of each column, full0 and fullF weights"""
        activations = DataGen.array_fullzeros(32)
        # weights = DataGen.array_fullzeros(512)
        weights = DataGen.array_fullff(512)
        outputs = []
        self.cim_processing(activations,weights,outputs)     
        outputs_theory = self.trans.output_theory(activations, weights)
        print(outputs)
        print('Theory: {} '.format(outputs_theory))
        with open(path_out,'a') as filea:
                filea.write("%s\n" % outputs)
        
    def offset_compen(self):
        """64 cycles operation: each time append a 4'b1111 on activations
        """
        activations = DataGen.array_fullzeros(32)
        weights = DataGen.array_fullzeros(512)
        # weights = DataGen.array_fullff(512)
        # Weights are modified to 0 later, so keep the weights for theory data calculation
        weights_theory = DataGen.array_fullzeros(512)  
        outputs = []
        for _ in range(65): # from 64 of 0 to 64 of 4'b1111: 65 cycles
            self.cim_processing(activations,weights,outputs)     
            outputs_theory = self.trans.output_theory(activations, weights_theory)
            print(outputs)
            print('Theory: {} '.format(outputs_theory))
            activations = DataGen.act_plus_f(activations)
            weights.clear()                         # Clear weight data
            with open(path_out,'a') as filea:
                filea.write("%s\n" % outputs)
            with open(path_outtheory,'a') as fileb:
                fileb.write("%s\n" % outputs_theory)
            self.clear_act_reg()                    # Clear activation flag
        
    def edges(self):
        activations = DataGen.array_fullzeros(32)
        # weights = DataGen.array_fullzeros(512)
        weights = DataGen.array_fullff(512)
        outputs = []
        for _ in range(16): # from 64 of 0 to 64 of 4'b1111: 16 cycles
            self.cim_processing(activations,weights,outputs)     
            outputs_theory = self.trans.output_theory(activations, weights)
            print(outputs)
            print('Theory: {} '.format(outputs_theory))
            activations = DataGen.act_plusone_each(activations)
            with open(path_out,'a') as filea:
                filea.write("%s\n" % outputs)
            with open(path_outtheory,'a') as fileb:
                fileb.write("%s\n" % outputs_theory)
    
    def plus_one(self):
        activations = DataGen.array_fullzeros(32)
        # weights = DataGen.array_fullzeros(512)
        weights = DataGen.array_fullff(512)
        outputs = []
        for _ in range(961): # from 64 of 0 to 64 of 4'b1111: 961 cycles
            self.cim_processing(activations,weights,outputs)     
            outputs_theory = self.trans.output_theory(activations, weights)
            print(outputs)
            print('Theory: {} '.format(outputs_theory))
            activations.reverse()
            activations = DataGen.act_plus_one(activations)
            activations.reverse()
            with open(path_out,'a') as filea:
                filea.write("%s\n" % outputs)
            with open(path_outtheory,'a') as fileb:
                fileb.write("%s\n" % outputs_theory)
            self.access_reg()

    def act_shift_append(self):
        activations = DataGen.array_fullzeros(32)
        # weights = DataGen.array_random(512)
        # weights = DataGen.array_fullff(512)
        weights = DataGen.array_random(512)
        with open(path_wei,'a') as filew:
            filew.write("%s\n" % weights)
        weights_theory = weights.copy() # keep weights for theory calculation
        outputs = []
        outputs_scale = []
        for _ in range(130): # append act data from all 0 to 64 act (65 cycles)
            self.cim_processing(activations,weights,outputs)   
            self.clear_act_reg()                    # Clear activation flag  
            
            self.cim_processing_scale(activations,weights,outputs_scale)  
               
            outputs_theory = self.trans.output_theory(activations, weights_theory)
            
            activations = DataGen.act_append_random(activations)
            weights.clear()                         # Clear weight data
            with open(path_out,'a') as fout:
                fout.write("%s\n" % outputs)
            with open(path_out_scale,'a') as fout_s:
                fout_s.write("%s\n" % outputs_scale)
            with open(path_outtheory,'a') as fout_theory:
                fout_theory.write("%s\n" % outputs_theory)
            self.clear_act_reg()                    # Clear activation flag
    # ----------------------------------------------------#
    # Function for One cycle of MAC Operation 
    # ----------------------------------------------------#
    def access_reg(self):
        """Access inner registers of the chip
        """
        self.trans.reset_host()
        # Prepare the bytearray to be written into FIFOA
        w_to_reg=bytearray(0)
        self.trans.wdata_fifoa_append(0x14,0x0090,w_to_reg)  # Set Start Bit to 9
        self.trans.wdata_fifoa_append(0x00,0x0003,w_to_reg)  # Clear status of Chip
        self.trans.wdata_fifoa_append(0x2C,0x0003,w_to_reg)  # Enable weight and actvation writing
        self.trans.wdata_fifoa_append(0x00,0x0003,w_to_reg)  # Clear status of Chip 
        self.trans.rdata_fifob_append(0x00,w_to_reg)         # 2x32bit in FIFOB
        self.trans.rdata_fifob_append(0x10,w_to_reg)   
        self.trans.rdata_fifob_append(0x14,w_to_reg) 
        self.trans.rdata_fifob_append(0x2C,w_to_reg)  
        # Pipe data into inner regs
        self.trans.pipe_data_in(w_to_reg)
        # Read out data from those address
        self.trans.pipe_data_out(num=4) 
        # Number of regs to be read, num must be even numbers
    def clear_act_reg(self):
        self.trans.reset_host()
        w_to_reg=bytearray(0)
        self.trans.wdata_fifoa_append(0x00,0x0001,w_to_reg)  # Clear status of Activation ready
        self.trans.wdata_fifoa_append(0x00,0x0001,w_to_reg)  # Clear status of Activation ready
        # Pipe data into inner regs
        self.trans.pipe_data_in(w_to_reg)
    # ----------------------------------------------------#
    def cim_processing(self, activations:bytearray, weights:bytearray, outputs:list):
        """One cycle of MAC Operation
        """
        self.trans.update_wires()
        if len(weights) !=0:
            self.trans.write_weights(weights)               # Write weights only when new weight data is avaliable
        self.trans.write_activations(activations)           # Write activations
        self.trans.mac_assert_finish() 
        outdata_re = self.trans.get_640b_out()
        self.trans.decode_out(outdata_re, outputs)
    # ----------------------------------------------------#
    def cim_processing_scale(self, activations:bytearray, weights:bytearray, outputs:list):
        """One cycle of MAC Operation with activation scaling
        """
        self.trans.update_wires()
        # if len(weights) !=0:
        #     self.trans.write_weights(weights)         # Write weights only when new weight data is avaliable
        activations_new, scale_factor = DataGen.act_scale(activations)
        print('Scale: {} '.format(scale_factor))   
        self.trans.write_activations(activations_new)     # Write activations

        self.trans.mac_assert_finish() 

        outdata_re = self.trans.get_640b_out()
        self.trans.decode_out(outdata_re, outputs)
        for i in range(64):
            outputs[i] = (outputs[i]/scale_factor)
    # ----------------------------------------------------#
    
# ----------------------------------------------------#
#            Main Function 
# ----------------------------------------------------#
if __name__ == "__main__":
    # (1) Config logger to have a pretty logging console
    setup_logger('CIM_Process', logging.INFO)
    # (2) Instantiate the main control class
    fpga_main = FpgaFunc()
    # FPGA: Initialization
    fpga_main.fpga_init()
    fpga_main.run_host()
