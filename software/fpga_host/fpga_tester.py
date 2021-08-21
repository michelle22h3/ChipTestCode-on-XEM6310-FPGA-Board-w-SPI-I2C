"""
This module exports the FPGA tester to communicate between host end (PC) and FPGA.
"""
import getpass
import logging
import sys
from collections import OrderedDict, namedtuple
from datetime import datetime
from enum import Enum

import ok

SUCCESS = ok.okCFrontPanel.NoError  # Alias for `SUCCESS` constant


class EndpointType(Enum):
    """Enum type for different endpoint types in OK front panel."""
    WIRE_IN = 0
    WIRE_OUT = 1
    TRIGGER_IN = 2
    TRIGGER_OUT = 3
    PIPE_IN = 4
    PIPE_OUT = 5

    def has_okEH(self):
        """Returns true if the endpoint type contains the okEH (control signal from slave to host)."""
        okEH_set = {EndpointType.WIRE_OUT, EndpointType.TRIGGER_OUT, EndpointType.PIPE_IN, EndpointType.PIPE_OUT}
        return self in okEH_set


class FPGATester:
    """Class implements the host tester (PC end) for FPGA to communicate with chip."""

    # Address map for FPGA. The valid address range for different endpoint types can be found in manual:
    # http://assets00.opalkelly.com/library/FrontPanel-UM.pdf
    # Each entry is stored in the dictionary as "name": AddrMapEntry
    AddrMapEntry = namedtuple("AddrMapEntry", ["type", "address"])  # Data type for each address map entry
    ADDR_MAP = OrderedDict([
        ("SW_RST", AddrMapEntry(EndpointType.WIRE_IN, 0x07)),  # Software reset pin address
        ("ITF_SEL", AddrMapEntry(EndpointType.WIRE_IN, 0x17)),  # ITF Selection signal
        ("STA_CHIP", AddrMapEntry(EndpointType.WIRE_OUT, 0x27)),  # Status of CIM chip
        ("FIFOB_EMPTY", AddrMapEntry(EndpointType.WIRE_OUT, 0x37)), # 1 means FIFOB is empty
        ("SPI_CONFIG", AddrMapEntry(EndpointType.TRIGGER_IN, 0x47)),  # Config SPI Master
        ("FIFOA_IN_DATA", AddrMapEntry(EndpointType.PIPE_IN, 0x87)),    # data into FIFO_A
        ("FIFOB_OUT_DATA", AddrMapEntry(EndpointType.PIPE_OUT, 0xA7)),    # data from FIFO_B
    ])
    W_BYTES = 64
    R_BYTES = 16

    def __init__(self, fpga_bit_file, debug=False):
        """
        Constructor of FPGA tester.
        :param fpga_bit_file: path of the fpga bitstream file.
        :param debug: optional flag for debug purpose due to the lack of FPGA device.
        """
        self.logger = logging.getLogger(self.__class__.__name__)
        self.debug = debug
        self.device = self.initialize_device(fpga_bit_file)
    # ------------- Device Initialization -------------#
    def initialize_device(self, fpga_bit_file):
        """
        Initialize FPGA device and sanity check the connection of FPGA.
        :param fpga_bit_file: filename of FPGA bitstream.
        :return: reference to the Opal Kelly FrontPanel-enabled device.
        """
        device = ok.okCFrontPanel()
        if device.OpenBySerial("") != SUCCESS:  # Open the first available device
            self.logger.critical("A device could not be opened. Is one connected?")
            if not self.debug:
                return None

        # Get some general information about the device
        device_info = ok.okTDeviceInfo()
        if device.GetDeviceInfo(device_info) != SUCCESS:
            self.logger.critical("Unable to retrieve device information.")
            if not self.debug:
                return None
        self.logger.info("Product: {}".format(device_info.productName))
        self.logger.info("Firmware version: {}.{}".format(device_info.deviceMajorVersion,
                                                          device_info.deviceMinorVersion))
        self.logger.info("Serial Number: {}".format(device_info.serialNumber))
        self.logger.info("Device ID: {}".format(device_info.deviceID))

        device.LoadDefaultPLLConfiguration()  # Config PLL with settings stored in EEPROM

        if device.ConfigureFPGA(fpga_bit_file) != SUCCESS:  # Download Xilinx config bit-file to FPGA
            self.logger.critical("Failed to config FPGA with bitstream file {}.".format(fpga_bit_file))
            if not self.debug:
                return None

        if device.IsFrontPanelEnabled() != True: # This line is always showed on during testing
            self.logger.critical("okHostInterface is not installed in the FPGA configuration.")
            if not self.debug:
                return None

        return device
    # ----------------------------------------------------#
    def reset(self):
        """Reset FPGA hardware."""
        # Generate a falling edge @ sw reset address (write 1 first then 0)
        self.write_wire_in(self.ADDR_MAP["SW_RST"].address, value=0x00, mask=0x01)
        self.write_wire_in(self.ADDR_MAP["SW_RST"].address, value=0x01, mask=0x01)
        self.write_wire_in(self.ADDR_MAP["SW_RST"].address, value=0x00, mask=0x01)
        self.logger.info("Reset FPGA System")

    def config_spimaster(self):
        # Configure SPI Master using a config trigger signal
        self.write_trigger_in(self.ADDR_MAP["SPI_CONFIG"].address, 0) 
        self.logger.info("SPI Master is configured")

    def led_cntl(self, value_led):
        self.write_wire_in(self.ADDR_MAP["SW_RST"].address, value_led, mask=0x3E)

    def itf_selection(self, value):
        # Input: integer value
        """Selection of I2C and SPI, 0x00(0) means I2C and 0x01(1) means SPI"""
        self.write_wire_in(self.ADDR_MAP["ITF_SEL"].address, value, mask=0x01)

    def fifob_empty(self):
        """Find out if FIFO_B is empty, return True or False"""
        # True means fifob is not empty, false means fifob is empty
        return self.read_wire_out(self.ADDR_MAP["FIFOB_EMPTY"].address) == 1
    
    # ----------------------------------------------------#
    def fifotest_write(self,fifodata):
        self.write_pipe_in(self.ADDR_MAP["FIFOA_IN_DATA"].address, fifodata)

    def fifotest_read(self,fifob_odata):    
        self.read_pipe_out(self.ADDR_MAP["FIFOB_OUT_DATA"].address, fifob_odata)


    # ----------------- Write and read Endpoints ------------------ #
     # Write Wire In
    def write_wire_in(self, addr, value, mask=0x01):   
        """
        Helper to write the specified value to the `wire_in` endpoint in FPGA.
        :param addr: 8-bit address of the `wire_in`.
        :param value: 32-bit integer of value to be written into.
        :param mask: 32-bit mask applied to the write value (1 bit LSB by default).
        """
        # Detect value and mask is proper
        assert 0 <= value <= 2 ** 32 - 1 and 0 <= mask <= 2 ** 32 - 1
        self.device.SetWireInValue(addr, value, mask)
        self.device.UpdateWireIns()

    # Read Wire Out
    def read_wire_out(self, addr):                       
        """
        Helper to read the value of `wire_out` endpoint in FPGA.
        :param addr: 8-bit address of the `wire_out`.
        :return: 32-bit `wire_out` data.
        """
        self.device.UpdateWireOuts()
        return self.device.GetWireOutValue(addr)
    
    # Write Trigger In
    def write_trigger_in(self, addr, bit):
        """
        Helper to write the value of `Trigger_in` endpoint in FPGA.
        :param addr: 8-bit address of the `Trigger_in`
        :bit:The specific bit of the trigger to activate.
        :return: NoError - Operation completed successfully.
        """
        assert 0 <= bit <= 2 ** 32 - 1
        self.device.ActivateTriggerIn(addr, bit)

    # Write Pipe In
    def write_pipe_in(self, addr, data):
        """
        Helper to write the specified data to the `pipe_in` endpoint in FPGA.
        :param addr: 8-bit address of the `pipe_in`.
        :param data: data of type bytearray to be written to `pipe` endpoint.
        the 'data' parameter is mutable type bytearray
        """
        self.device.WriteToPipeIn(addr, data)

    # Read Pipe Out
    def read_pipe_out(self, addr, data):
        """
        Helper to read the data from the `pipe_out` endpoint in FPGA.
        :param addr: 8-bit address of the `pipe_out`.
        :param data: read data will be placed (change in-place) in the data.    
        """
        self.device.ReadFromPipeOut(addr, data)

