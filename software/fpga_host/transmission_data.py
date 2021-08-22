import imp
import time
import logging
from fpga_host.data_gen import DataGen
from fpga_host.logger import setup_logger
class trans_data:

    def __init__(self, fpga_tester):
        self.fpga_tester = fpga_tester
        self.loggerset = setup_logger(self.__class__.__name__, logging.DEBUG)
        self.logger = logging.getLogger(self.__class__.__name__)

    def reset_host(self):
        """Program to run the host python program."""
        # ----------------------------------------------------#  
        # Main procedure for FPGA
        self.fpga_tester.reset()
        self.fpga_tester.config_spimaster()
        self.fpga_tester.itf_selection(1) # 0 means select I2C
        self.fpga_tester.led_cntl(0x3E)

    def test_indirwr(self):
        # ----------------------------------------------------#  
        # Generate data and Writing Process
        dataout =DataGen.full_zeros(16)
        write_dataA = DataGen.indir_write(0x10, 0x0733)
        print (write_dataA)
        self.fpga_tester.fifo_write(write_dataA)  # Write 16-bit data into \x10
        write_dataA = DataGen.indir_write(0x14, 0x77FF)
        print (write_dataA)
        self.fpga_tester.fifo_write(write_dataA)  # Write 16-bit data into \x14
        # ----------------------------------------------------#  
        # Generate data and Reading Process
        read_dataA = DataGen.indir_read(0x10)
        self.fpga_tester.fifo_write(read_dataA)  # Write command into FIFO
        print (self.fpga_tester.fifob_empty())
        self.fpga_tester.fifo_read(dataout) # Read out data
        print(dataout[0], dataout[4])

        read_dataA = DataGen.indir_read(0x14)
        self.fpga_tester.fifo_write(read_dataA)  # Write command into FIFO
        print (self.fpga_tester.fifob_empty())
        self.fpga_tester.fifo_read(dataout) # Read out data
        print(dataout[0], dataout[4])
        self.logger.info('Processing finish')
        time.sleep(1)

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

    def pipeout_data(self, size:int):
        if self.fpga_tester.fifob_empty() == False:
            self.logger.info('Data is fetched from inner reg to FIFO, start reading FIFO...')
        dataout = DataGen.full_zeros(size*8)
        self.fpga_tester.fifo_read(dataout)
        for j in range(size*2):
            self.logger.debug('Read out data: {}'.format(dataout[4*j]))
        # self.logger.debug('Read out data: {} from Address {}'.format(data, hex(ind_addr)))

    def write_weights(self, weights:int):
        """"Input: 4096-bit, 1-bit/w, in Bytearray type (one iterm stores 8 weights)"""
        weights_256sets = weights.to_bytes(256, "big")
        self.logger.warning('Start Sending 4096 bit weight data to chip...')
        self.ind_write_reg(0x2C, 0x0001)
        for i in range(256):
            self.ind_write_reg(0x30, weights_256sets[i])
    
    def write_activations(self, activations:int):
        """Input: 256-bit, 4-bit/act, in Bytearray type (one iterm stores 2 activations)"""
        activations_16sets = activations.to_bytes(16, "big")
        self.logger.warning('Start Sending 256 bit activation data to chip...')
        self.ind_write_reg(0x2C, 0x0002)
        for j in range(16):
            self.ind_write_reg(0x34, activations_16sets[j])
    
    def get_outputs(self, outputs:int):
        """Get 640-bit output data from chip, and make them into desired format"""
        outputs = bytearray(80)
        self.logger.warning('Start fetching 640 bit output data from chip...')
        r_pattern_16byte = DataGen.indir_read(0x38)
        for i in range(80):
            self.fpga_tester.fifo_write(r_pattern_16byte)
        
        

        
        
