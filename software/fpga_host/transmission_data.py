import time
import logging
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
        self.fpga_tester.itf_selection(1) # 0 means select I2C
        self.fpga_tester.led_cntl(0x3E)
    # ----------------------------------------------------#
    # Indirect write and read of one inner register
    # ----------------------------------------------------#   
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
        while self.fpga_tester.fifob_empty() == True:
            time.sleep(0.1)
        self.logger.info('Data is fetched from inner reg to FIFO, start reading FIFO...')
        dataout = DataGen.full_zeros(16)
        self.fpga_tester.fifo_read(dataout)
        data_twobyte = bytearray([dataout[0], dataout[4]])
        self.logger.debug('Read out data: {}: {}\{} from Address {}'.format(data_twobyte,hex(dataout[0]),hex(dataout[4]), hex(ind_addr)))
    # ----------------------------------------------------#
    # Data transmission for MAC operation
    # ----------------------------------------------------#
    def write_weights(self, weights:int):
        """"Input: 4096-bit, 1-bit/w, in Bytearray type (one iterm stores 8 weights)"""
        weights_256sets = weights.to_bytes(256, "big")
        self.logger.warning('Start Sending 4096 bit weight data to chip...')
        self.ind_write_reg(0x2C, 0x0001)
        for i in range(256):
            self.ind_write_reg(0x30, weights_256sets[i])

    # Return true if weight writing is finished
    def weight_w_finish(self): 
        """Read the status of chip to see if weight writing is finished"""
        data_twobyte_r = bytearray(2)
        self.ind_read_reg(0x00, data_twobyte_r)
        if data_twobyte_r == 2:
            return True
        else:
            return False

    def write_activations(self, activations:int):
        """Input: 256-bit, 4-bit/act, in Bytearray type (one iterm stores 2 activations)"""
        activations_16sets = activations.to_bytes(16, "big")
        self.logger.warning('Start Sending 256 bit activation data to chip...')
        self.ind_write_reg(0x2C, 0x0002)
        for j in range(16):
            self.ind_write_reg(0x34, activations_16sets[j])

    # Return true if activation assertion is finished
    def act_w_finish(self): 
        """Read the status of chip to see if weight writing is finished"""
        data_twobyte_r = bytearray(2)
        self.ind_read_reg(0x00, data_twobyte_r)
        if data_twobyte_r == 3:
            return True
        else:
            return False
    # ----------------------------------------------------#
    # Send 16 byte data pattern for 40 times to read out 640bit (40x16) output data
    def askfor_outputs(self):
        """Request for 640-bit output data from chip"""
        self.logger.warning('Start requesting output data from chip...')
        r_pattern_16byte = DataGen.indir_read(0x38)
        for i in range(40): # Read data from address 0x38 for 40 times
            self.fpga_tester.fifo_write(r_pattern_16byte)
            self.logger.debug('Send out data pattern: {}'.format(r_pattern_16byte))

    def get_outputs(self, outputs):
        """Get 640-bit output data from chip, and make them into desired format"""
        self.logger.warning('Start fetching 640 bit output data from chip...')
        data_received = bytearray(320)
        self.fpga_tester.fifo_read(data_received)
        outputs = bytearray([data_received[0], data_received[4]])
        for i in range(8, 320, 4):
            outputs.append(data_received[i])



        
        

        
        
