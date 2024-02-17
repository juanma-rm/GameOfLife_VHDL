###################################################################################
# Usage
###################################################################################

# See README.txt

###################################################################################
# Imports
###################################################################################

# General
import logging
import os
import cocotb
import cocotb_test.simulator
from cocotb.log import SimLog
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from cocotb.handle import Release, Force

# Network
from scapy.layers.l2 import Ether, ARP
from scapy.layers.inet import IP, UDP
from cocotbext.eth import XgmiiFrame, XgmiiSource, XgmiiSink

# AXI
from cocotbext.axi import AxiBus, AxiRam, AxiLiteMaster, AxiLiteBus

###################################################################################
# TB class (common for all tests)
###################################################################################

class TB:

    def __init__(self, dut):
        self.dut = dut

        self.log = SimLog("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk_i, 1000, units="ns").start())

    async def init(self):
        # Reset
        self.dut.rst_i.value = 0
        self.dut.start_i.value = 0
        for _ in range(10): await RisingEdge(self.dut.clk_i)
        self.dut.rst_i.value = 1
        for _ in range(10): await RisingEdge(self.dut.clk_i)
        self.dut.rst_i.value = 0

###################################################################################
# Test: run_test 
# Stimulus: -
# Expected:
# - p_mod outputs 8 most significative bits of count
# - p_mod set to 0 during reset
###################################################################################

@cocotb.test()
async def run_test_board_to_frame(dut):

    # Initialize TB
    tb = TB(dut)
    await tb.init()
    
    # Generate board
    frame_rows = int(tb.dut.frame_resolution_v_c.value/tb.dut.ratio_expansion_c.value)
    frame_cols = int(tb.dut.frame_resolution_h_c.value/tb.dut.ratio_expansion_c.value)
    # tb.dut.data_all_i.value = 0xA0A0B0B0C0C0D0D0
    for cell_pos in range(0, frame_rows*frame_cols):
        tb.dut.data_all_i[cell_pos].value = cell_pos % 2
        for _ in range(1): await RisingEdge(tb.dut.clk_i)
    
    # Test normal operation
    tb.dut.m_axis_tready.value = 1
    for _ in range(10): await RisingEdge(tb.dut.clk_i)
    tb.dut.start_i.value = 1
    for _ in range(int(frame_rows*frame_cols/2) + 5): await RisingEdge(tb.dut.clk_i) # Wait for 1/2 frame aprox
    
    # Test backpressure
    tb.dut.m_axis_tready.value = 0
    for _ in range(10): await RisingEdge(tb.dut.clk_i)
    
    # Test the rest of the frame
    tb.dut.m_axis_tready.value = 1
    for _ in range(int(frame_rows*frame_cols/2)): await RisingEdge(tb.dut.clk_i)
    
    # Leave some extra time to make visualisation clearer
    for _ in range(10): await RisingEdge(tb.dut.clk_i)
    
###################################################################################
# cocotb-test flow (alternative to Makefile flow)
###################################################################################

tests_path = os.path.abspath(os.path.dirname(__file__))
rtl_dir = os.path.abspath(os.path.join(tests_path, '..', '..', '..', 'rtl'))

def test_board_to_frame(request):
    dut = "board_to_frame"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    vhdl_sources = [
        os.path.join(rtl_dir, f"{dut}.vhd"),
        os.path.join(rtl_dir, "utils_pkg.vhd"),
    ]
    
    parameters = {}
    # parameters['A'] = "value"
    extra_env = {f'PARAM_{k}': str(v) for k, v in parameters.items()}
    
    plus_args = ["-t", "1ps"]
    # plus_args['-t'] = "1ps"

    sim_build = os.path.join(tests_path, "sim_build",
        request.node.name.replace('[', '-').replace(']', ''))

    cocotb_test.simulator.run(
        python_search=[tests_path],
        vhdl_sources=vhdl_sources,
        toplevel=toplevel,
        module=module,
        parameters=parameters,
        sim_build=sim_build,
        extra_env=extra_env,
        plus_args=plus_args,
    )
