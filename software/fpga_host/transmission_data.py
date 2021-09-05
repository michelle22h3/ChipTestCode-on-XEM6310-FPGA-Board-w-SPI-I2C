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
        """Call the functions to do reset and configuration."""
        self.fpga_tester.reset()
        self.fpga_tester.config_spimaster()
        self.fpga_tester.itf_selection(0) # 0 means select I2C and 1 means SPI
        self.fpga_tester.led_cntl(0x3E)   # LED Mask is 3E
        self.fpga_tester.fifob_fullthresh(0x4F) 
        self.fpga_tester.fifob_progfull()
    # ----------------------------------------------------#
    # Indirect write and read of ONE inner register
    # ----------------------------------------------------#   
    def emptyfifo(self):
        #data = bytearray(32)
        #self.fpga_tester.fifo_read(data)
        #self.logger.warning('Read out dummy data: {}'.format(data))
        self.fpga_tester.fifob_empty()
        self.fpga_tester.fifob_progfull()

    def ind_write_reg(self, ind_addr:int, ind_data:int):
        """With an 8-b addr, 16-b data, perform an indirect writing process"""
        assert 0 <= ind_addr <=0xFF and 0 <= ind_data <= 0xFFFF, "invalid inputs"
        w_pattern_16byte = DataGen.indir_write(ind_addr, ind_data)
        self.logger.debug('Write 16-bit data: {} into inner reg: {}'.format(hex(ind_data), hex(ind_addr)))
        self.fpga_tester.fifo_write(w_pattern_16byte)

    def ind_read_reg(self, ind_addr:int):
        """With an 8-b addr, 16-b data, perform an indirect writing process"""
        assert 0 <= ind_addr <=0xFF, "invalid inputs"
        r_pattern_16byte = DataGen.indir_read(ind_addr)
        self.fpga_tester.fifo_write(r_pattern_16byte)
        #while self.fpga_tester.fifob_empty():
        time.sleep(0.1)
        self.logger.info('Data is fetched from inner reg to FIFO, start reading FIFO...')
        dataout = DataGen.full_zeros(16)
        self.fpga_tester.fifo_read(dataout)
        data_twobyte = bytearray([dataout[0], dataout[4]])
        self.emptyfifo()
        self.logger.critical('Read out data: {}: {}\{} from Address {}'.format(data_twobyte,hex(dataout[0]),hex(dataout[4]), hex(ind_addr)))
    # ----------------------------------------------------#
    # Data transmission for MAC operation
    # ----------------------------------------------------#
    def write_weights(self, weights:bytearray):
        """"Input: 4096-bit, 1-bit/w, in Bytearray type (one iterm stores 8 weights)"""
        self.logger.warning('Start Sending 4096 bit weight data to chip...')

        for i in range(0, 512, 2):
            weights_2byte = int.from_bytes(weights[i:i+2], "big")
            self.ind_write_reg(0x30, weights_2byte)

    def write_activations(self, activations:bytearray):
        """Input: 256-bit, 4-bit/act, in Bytearray type (one iterm stores 2 activations)"""
        self.logger.warning('Start Sending 256 bit activation data to chip...')

        for j in range(0, 32, 2):
            act_2bytes =int.from_bytes(activations[j:j+2], "big")
            self.ind_write_reg(0x34, act_2bytes)

    def mac_assert_finish(self):
        while not self.fpga_tester.sta_chip() == 3:
            time.sleep(0.1)
        self.logger.warning('MAC assert finish')
    # ----------------------------------------------------#
    # Send 16 byte data pattern for 40 times to read out 640bit (40x16) output data
    def askfor_outputs(self):
        """Request for 640-bit output data from chip"""
        self.logger.warning('Start requesting output data from chip...')
        r_pattern_16byte = DataGen.indir_read(0x38)
        for _ in range(40): # Read data from address 0x38 for 40 times
            self.fpga_tester.fifo_write(r_pattern_16byte)
            #self.logger.debug('Send out data pattern: {}'.format(r_pattern_16byte))

    def get_outputs(self):
        """Get 640-bit output data from chip, and make them into desired format"""
        # while self.fpga_tester.fifob_progfull() == False:
        #     time.sleep(0.1)
        self.logger.warning('Start reading data from FPGA...')
        data_received = bytearray(320)
        self.fpga_tester.fifo_read(data_received)
        outputs = bytearray([data_received[0], data_received[4]])
        for i in range(8, 320, 4):
            outputs.append(data_received[i])
        self.logger.info('Read outputs: {}'.format(outputs))
        return outputs
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
                elif j in [1,2]:   ## Skip 3 MSB if output is 7 bit
                    continue
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
