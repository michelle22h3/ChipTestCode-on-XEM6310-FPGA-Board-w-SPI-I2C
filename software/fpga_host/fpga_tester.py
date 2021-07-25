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
        ("SW_RST", AddrMapEntry(EndpointType.WIRE_IN, 0x10)),  # Software reset pin address
        ("CALC_DONE", AddrMapEntry(EndpointType.TRIGGER_OUT, 0x60)),  # Calculation done status trigger
        ("ACT_OUT_RX_DONE", AddrMapEntry(EndpointType.TRIGGER_OUT, 0x61)),  # Activation output RX done status trigger
        ("ACT_IN_DATA", AddrMapEntry(EndpointType.PIPE_IN, 0x80)),  # Activation input data FIFO
        ("WEIGHT_DATA", AddrMapEntry(EndpointType.PIPE_IN, 0x81)),  # Weight data FIFO
        ("ACT_OUT_DATA", AddrMapEntry(EndpointType.PIPE_OUT, 0xA0)),  # Activation output data FIFO
    ])

    # Expected data bytes of each tensor
    ACT_IN_BYTES = 64
    WEIGHT_BYTES = 512
    ACT_OUT_BYTES = 64

    def __init__(self, fpga_bit_file, debug=False):
        """
        Constructor of FPGA tester.
        :param fpga_bit_file: path of the fpga bitstream file.
        :param debug: optional flag for debug purpose due to the lack of FPGA device.
        """
        self.logger = logging.getLogger(self.__class__.__name__)
        self.debug = debug
        self.device = self.initialize_device(fpga_bit_file)

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

        if device.IsFrontPanelEnabled() != SUCCESS:
            self.logger.critical("okHostInterface is not installed in the FPGA configuration.")
            if not self.debug:
                return None

        return device

    def reset(self):
        """Reset FPGA hardware."""
        # Generate a falling edge @ sw reset address (write 1 first then 0)
        self.write_wire_in(self.ADDR_MAP["SW_RST"].address, value=0x01)
        self.write_wire_in(self.ADDR_MAP["SW_RST"].address, value=0x00)

    def send_act_in(self, act_in_data):
        """Send the specified activation input data bytearray to the FPGA."""
        assert len(act_in_data) == self.ACT_IN_BYTES, "Activation data is expected to be of 64B."
        self.logger.info("Start sending activation input data to FPGA.")
        self.write_pipe_in(self.ADDR_MAP["ACT_IN_DATA"].address, act_in_data)

    def send_weight(self, weight_data):
        """Send the specified weight data bytearray to the FPGA."""
        assert len(weight_data) == self.WEIGHT_BYTES, "Weight data is expected to be of 512B."
        self.logger.info("Start sending weight data to FPGA.")
        self.write_pipe_in(self.ADDR_MAP["WEIGHT_DATA"].address, weight_data)

    def receive_act_out(self, act_out_data):
        """Receive the calculated activation output from the FPGA."""
        assert len(act_out_data) == self.ACT_OUT_BYTES, "Activation data is expected to be of 64B."
        self.logger.info("Start receiving calculated activation output data from FPGA.")
        self.read_pipe_out(self.ADDR_MAP["ACT_OUT_DATA"].address, act_out_data)

    def calc_done(self):
        """Indicator of calculation finishes."""
        return self.read_trigger_out(self.ADDR_MAP["CALC_DONE"].address)

    def act_out_rx_done(self):
        """Indicator of receiving all activation output."""
        return self.read_trigger_out(self.ADDR_MAP["ACT_OUT_RX_DONE"].address)

    def write_wire_in(self, addr, value, mask=0x01):
        """
        Helper to write the specified value to the `wire_in` endpoint in FPGA.
        :param addr: 8-bit address of the `wire_in`.
        :param value: 32-bit integer of value to be written into.
        :param mask: 32-bit mask applied to the write value (LSB by default).
        """
        assert 0 <= value <= 2 ** 32 - 1 and 0 <= mask <= 2 ** 32 - 1
        self.device.SetWireInValue(addr, value, mask)
        self.device.UpdateWireIns()

    def read_trigger_out(self, addr, mask=0x01):
        """
        Helper to read the value of LSB of `trigger_out` endpoint in FPGA.
        :param addr: 8-bit address of the `trigger_out`.
        :param mask: 32-bit mask applied to trigger value (LSB by default).
        :return: LSB of the `trigger_out` data.
        """
        self.device.UpdateTriggerOuts()
        return self.device.IsTriggered(addr, mask)

    def write_pipe_in(self, addr, data):
        """
        Helper to write the specified data to the `pipe_in` endpoint in FPGA.
        :param addr: 8-bit address of the `pipe_in`.
        :param data: data of type bytearray to be written to `pipe` endpoint.
        """
        self.device.WriteToPipeIn(addr, data)

    def read_pipe_out(self, addr, data):
        """
        Helper to read the data from the `pipe_out` endpoint in FPGA.
        :param addr: 8-bit address of the `pipe_out`.
        :param data: read data will be placed (change in-place) in the data.
        """
        self.device.ReadFromPipeOut(addr, data)

    def gen_config_header(self, config_file):
        """
        Helper to generate the verilog configure header.
        :param config_file: file name of config header to be written.
        """
        cmdline = " ".join([sys.executable] + sys.argv)
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        header_comment = "// Config file automatically generated by cmd: `{}`\n".format(cmdline)
        header_comment += "// User: {}; Time: {}\n".format(getpass.getuser(), current_time)

        header_guard_begin = "\n".join(["`ifndef __CONFIG_VH__", "`define __CONFIG_VH__"])
        header_guard_end = "`endif"

        data_bytes = "\n".join(["`define ACT_IN_BYTES {}".format(self.ACT_IN_BYTES),
                                "`define WEIGHT_BYTES {}".format(self.WEIGHT_BYTES),
                                "`define ACT_OUT_BYTES {}".format(self.ACT_OUT_BYTES)])

        addr_map_list, num_endpoints = [], 0
        for key, value in self.ADDR_MAP.items():
            addr_map_list.append("`define {} 8'h{:02X}".format(key + "_ADDR", value.address))
            if value.type.has_okEH():
                num_endpoints += 1

        with open(config_file, "w") as fp:
            fp.write(header_comment + "\n")
            fp.write(header_guard_begin + "\n")
            fp.write("\n// Number of bytes of data FIFO\n")
            fp.write(data_bytes + "\n")
            fp.write("\n// Address map\n")
            fp.write("\n".join(addr_map_list) + "\n")
            fp.write("\n// Number of endpoints requiring `okEH`" + "\n")
            fp.write("`define NUM_ENDPOINTS {}".format(num_endpoints) + "\n")
            fp.write("\n" + header_guard_end + "\n")

        self.logger.info("Successfully generate the RTL config file to `{}`.".format(config_file))
