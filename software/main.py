"""
This is the top-level program.
"""

import os
import subprocess
import sys
import time

# Sanity check to make sure Python interpreter is with the compatible version with `OK` package
assert sys.version_info.major == 3 and sys.version_info.minor == 5, "OK FrontPanel only complies with Python 3.5"

from fpga_host.cmd_parser import CmdlineParser
from fpga_host.data_gen import DataGen
from fpga_host.fpga_tester import FPGATester
from fpga_host.logger import setup_logger

DEBUG = True  # Knob to bypass the error w/o FPGA


def run_host(fpga_tester, args):
    """Program to run the host python program."""
    # Generate synthetic data for test (random here)
    act_in_data_list = [0 if i % 2 == 0 else 1 for i in range(fpga_tester.ACT_IN_BYTES)]
    print(act_in_data_list)
    act_in_data = DataGen.list_2_bytearray(act_in_data_list)
    weight_data = DataGen.full_zeros(fpga_tester.WEIGHT_BYTES)
    act_out_data = DataGen.full_zeros(fpga_tester.ACT_OUT_BYTES)

    # Main procedure to invoke data transfer and calculation for FPGA
    fpga_tester.reset()
    fpga_tester.send_act_in(act_in_data)
    fpga_tester.send_weight(weight_data)

    # Polling over computation done
    while not fpga_tester.calc_done():
        fpga_tester.logger.info("Sleep 1 second to poll calculation finish again...")
        time.sleep(0.0001)

    # Send activation input and initiate output data transfer state
    fpga_tester.send_act_in(act_in_data)

    # Polling over all activation output received done
    while not fpga_tester.act_out_rx_done():
        fpga_tester.logger.info("Sleep 1 second to poll full activation output received again...")
        time.sleep(0.0001)

    # Read the calculated data
    fpga_tester.receive_act_out(act_out_data)

    # led = 0x0F

    # while True:
    #     led = led << 1 if led < 8 else 1
    #     time.sleep(0.3)
    #     fpga_tester.write_wire_in(fpga_tester.ADDR_MAP["SW_RST"].address, value=led, mask=0x0E )


def gen_config(fpga_tester, args):
    """Program to generate the RTL config file."""
    fpga_tester.gen_config_header(args.config_file)


def run_sim(fpga_tester, args):
    """Program to run the RTL behavior simulation."""
    act_in_data = DataGen.random_array(fpga_tester.ACT_IN_BYTES)
    weight_data = DataGen.random_array(fpga_tester.WEIGHT_BYTES)
    # In chip behavior model, we assume act_out = act_in + weight
    act_out_data = bytearray([(act_in + weight) % 256 for act_in, weight in zip(act_in_data, weight_data)])

    # Generate the memory initialization file for RTL behavior simulation
    DataGen.gen_mem_init(act_in_data, os.path.join(args.sim_path, "act_in.dat"))
    DataGen.gen_mem_init(weight_data, os.path.join(args.sim_path, "weight.dat"))
    DataGen.gen_mem_init(act_out_data, os.path.join(args.sim_path, "golden_ref.dat"))

    command = ["vsim", "-gui", "-do", "sim.do"]
    p = subprocess.Popen(command, cwd=args.sim_path, stdout=subprocess.PIPE, stderr=None, stdin=subprocess.PIPE,
                         universal_newlines=True)
    fpga_tester.logger.info("Start run behavior simulation of design...")
    stdout, _ = p.communicate()
    fpga_tester.logger.info(stdout)
    if p.returncode != 0:
        fpga_tester.logger.error("Simulation failed.")


def main():
    args = CmdlineParser().parse()
    setup_logger(FPGATester.__name__, args.log_level)  # Config logger to have a pretty logging console

    # Initialize FPGA tester and sanity check
    fpga_tester = FPGATester(args.fpga_bit, debug=DEBUG)
    if fpga_tester.device is None:
        sys.exit(1)

    # Invoke the corresponding sub-program
    programs = {"run_host": run_host, "gen_config": gen_config, "run_sim": run_sim}
    programs[args.action](fpga_tester, args)


if __name__ == "__main__":
    main()
