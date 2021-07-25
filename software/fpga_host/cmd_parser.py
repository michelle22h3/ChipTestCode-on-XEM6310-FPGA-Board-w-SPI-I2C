"""
This module exports the command line options parser of the program.
"""

import argparse


class CmdlineParser:

    def __init__(self):
        """Ctor of the cmdline option parser."""
        self.parser = argparse.ArgumentParser(description="Host software of chip test.")
        # Add supported cmdline options below. Check `add_argument` API description in the following link:
        # https://docs.python.org/3/library/argparse.html#argparse.ArgumentParser.add_argument
        # self.parser.add_argument("--input_file", type=str, default="zjy.png", help="Path of input file.")
        # self.parser.add_argument("--output_file", type=str, default="wxm.png", help="Path of destination file.")
        # self.parser.add_argument("--decrypt", action="store_true", help="Decrypt the input file.")
        self.parser.add_argument("--fpga_bit", type=str, default="../ise_workspace/fpgatop.bit",
                                 help="Path of FPGA bit stream file.")
        self.parser.add_argument("--log_level", type=str, default="INFO",
                                 choices=['NOTSET', 'DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'],
                                 help="Setup logging level for program.")
        self.parser.add_argument("--config_file", type=str, default="../hardware/verilog/config.vh",
                                 help="Generate RTL config file.")
        self.parser.add_argument("--sim_path", type=str, default="../hardware/sim",
                                 help="Path for RTL behavior simulation")
        self.parser.add_argument("--action", type=str, default="run_host",
                                 choices=["run_host", "gen_config", "run_sim"],
                                 help="Action of main software behavior.")

    def parse(self):
        """Parse the cmdline options and returns the parsing result."""
        return self.parser.parse_args()
