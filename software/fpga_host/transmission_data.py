    """ This module update signals of FPGA and 
        transmit data to FPGA in a proper format
    """
import time
import logging
import numpy as np
from fpga_host.data_gen import DataGen
from fpga_host.logger import setup_logger
class TransData:
    def __init__(self, fpga_tester):
        self.fpga_tester = fpga_tester
        self.logger = logging.getLogger('CIM_Process')
    # ----------------------------------------------------#  
    # Reset FPGA Host and logic
    # ----------------------------------------------------#  
    def reset_host(self):
        """Call the functions to do reset and do the configuration."""
        self.fpga_tester.reset()
        self.fpga_tester.config_spimaster()
        self.fpga_tester.itf_selection(0)        # 0 means select I2C and 1 means SPI
        self.fpga_tester.led_cntl(0x3E)          # LED Mask is 3E
        self.fpga_tester.fifob_fullthresh(0x50)  # Threshold is 80: 80(depth)x32 = 320x8 = 320 byte
        self.fpga_tester.fifob_empty()           # Check if FIFOB is empty
        self.fpga_tester.sta_chip()              # Check the status of chip: weight writing and MAC

    def update_wires(self):
        self.fpga_tester.fifob_fullthresh(0x50) 
        self.fpga_tester.fifob_empty()           
        self.fpga_tester.sta_chip()
    # ----------------------------------------------------#
    # Indirect write and read of ONE inner register
    # ----------------------------------------------------#   
    def wdata_fifoa_append(self, ind_addr:int, ind_data:int, w_pattern:bytearray):
        """With an 8-b addr, 16-b data, append data for an indirect writing """
        assert 0 <= ind_addr <=0xFF and 0 <= ind_data <= 0xFFFF, "invalid inputs"
        w_pattern_16byte = DataGen.indir_write(ind_addr, ind_data)
        w_pattern.extend(w_pattern_16byte)
    
    def rdata_fifob_append(self, ind_addr:int, w_pattern:bytearray):
        """With an 8-b addr, 16-b data, append data for an indirect writing """
        assert 0 <= ind_addr <=0xFF, "invalid inputs"
        r_pattern_16byte = DataGen.indir_read(ind_addr)
        w_pattern.extend(r_pattern_16byte)

    def pipe_data_in(self, data_to_fifoa):
        self.fpga_tester.fifo_write(data_to_fifoa)

    def pipe_data_out(self, num:int):
        dataout = bytearray(num*8) # 2x32bit/8 = 8 byte
        while self.fpga_tester.fifob_empty():
            time.sleep(0.1)
        self.fpga_tester.fifo_read(dataout)
        # print(dataout)
        # Every 8 byte, there is a 2-byte data
        for i in range(num):
            data_twobyte = [hex(dataout[i*8]), hex(dataout[i*8+4])]
            self.logger.critical('Read out data: {}: '.format(data_twobyte))
    # ----------------------------------------------------#
    # Data transmission for MAC operation
    # ----------------------------------------------------#
    def write_weights(self, weights:bytearray):
        """"Input: 4096-bit, 1-bit/w, in Bytearray type (one iterm stores 8 weights)"""
        self.logger.warning('Start Sending 4096 bit weight data to chip...')
        all_weights = bytearray(0)
        for i in range(0, 512, 2):
            weights_2byte = int.from_bytes(weights[i:i+2], "big")
            self.wdata_fifoa_append(0x30, weights_2byte, all_weights)
        self.pipe_data_in(all_weights)

    def write_activations(self, activations:bytearray):
        """Input: 256-bit, 4-bit/act, in Bytearray type (one iterm stores 2 activations)"""
        self.logger.warning('Start Sending 256 bit activation data to chip...')
        all_acts = bytearray(0)
        for j in range(0, 32, 2):
            act_2bytes =int.from_bytes(activations[j:j+2], "big")
            self.wdata_fifoa_append(0x34, act_2bytes, all_acts)
        self.pipe_data_in(all_acts)
    
    def mac_assert_finish(self):
        while not self.fpga_tester.sta_chip() == 3:
            time.sleep(0.1)
        self.logger.warning('MAC assert finish')
    # ----------------------------------------------------#
    # Output: 640 bit = 80 byte
    # Read out 1 byte from FIFOB: 32 bit contains 1 byte data
    # Get all the output data: 80x(32/4)= 320 
    # That is: 80 depth of data from FIFOB
    # ----------------------------------------------------#
    def get_640b_out(self):
        self.fetch_output()
        outputdata = bytearray(0)
        while self.fpga_tester.fifob_progfull() == False:
            time.sleep(0.1)
        data_received = bytearray(320)
        self.fpga_tester.fifo_read(data_received)
        for i in range(0, 320, 4):
            outputdata.append(data_received[i])
        # print(outputdata)
        return outputdata
        
    def fetch_output(self):
        askdata = bytearray(0)
        for _ in range(40): # Read address of the 16-bit data for 40 times
            self.rdata_fifob_append(0x38, askdata)
        self.pipe_data_in(askdata)

    # ----------------------------------------------------#
    #    Functions: pre-processing and post processing    #
    # ----------------------------------------------------#
    def decode_out(self, data: bytearray, decode_data:list):
        """Decode CIM output bytearray into raw data list."""
        NUMS = 64
        BITS = 10
        decode_data.clear()
        for i in range(NUMS):  # Decode i-th number
            int_data, negative = 0, False
            for j in range(BITS):  # Decode j-th bit
                bit_loc = j * NUMS + i
                byte_idx, byte_offset = int(bit_loc // 8), 7 - int(bit_loc % 8)
                bit = (data[byte_idx] >> byte_offset) & 1
                if j == 0:  # MSB: sign bit
                    negative = bit == 1
                # elif j in [1,2,3]:   ## Skip 3 MSB if output is 7 bit (1 means 9, 2 means 8, 3 means 7)
                #     continue
                else:
                    # negate bit when positive
                    int_data = int_data * 2 - bit if negative else int_data * 2 + (1^bit)
                if j == BITS - 1:
                    int_data *= 2  # Double decoding data in custom format
            decode_data.append(int_data) 
        decode_data.reverse()   # From [0] to [63]
        return decode_data   
    # ----------------------------------------------------#
    def output_theory(self, activations: bytearray, weights: bytearray):
        weight_binary =  [self.access_bit(weights,i) for i in range(len(weights)*8)]
        for j in range(len(weight_binary)):
            if weight_binary[j] == 0:
                weight_binary[j] = -1
        weight_cal_a = np.array(weight_binary)
        weight_cal=np.reshape(weight_cal_a, (64,64))
        activation_int = [self.access_halfbyte(activations,i) for i in range(0, len(activations)*8, 4)]
        activation_cal = np.array(activation_int)
        output_theory = np.dot(weight_cal.T, activation_cal)
        output_theory_list = list(output_theory)
        output_theory_list.reverse()
        return output_theory_list
    # ----------------------------------------------------#
    def access_bit(self, data, num):
        base = int(num // 8)
        shift = int(num % 8)
        return (data[base] >> shift) & 0x1

    def access_halfbyte(self, data, num):
        base = int(num // 8)
        shift = int(num % 8)
        return (data[base] >> shift) & 0xF
