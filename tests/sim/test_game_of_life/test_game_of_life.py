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
from cocotb.triggers import RisingEdge, Timer
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
async def run_test_test_game_of_life(dut):

    # Initialize TB
    tb = TB(dut)
    await tb.init()
    
    tb.dut.m_axis_tready.value = 1
    
    # To visualise changes w/o long simulations, set the constants in game_of_life.vhd as following:
    # constant one_s_max_c : integer := 1000;
    # constant refresh_ticks_c  : integer := 100;
    
    # @todo proper stimulation
    
    # Short center (> 50 ms)
    # tb.dut.buttons_i.value = 0x1
    await Timer(1, units='ms')
    # buttons_s(0) <= '1'; wait for 60 ms;   buttons_s(0) <= '0'; wait for 20 us; 
    # # Short down (> 50 ms)
    # buttons_s(2) <= '1'; wait for 60 ms;   buttons_s(2) <= '0'; wait for 20 us; 
    # # Short center (> 50 ms)
    # buttons_s(0) <= '1'; wait for 60 ms;   buttons_s(0) <= '0'; wait for 20 us; 
    # # Long center (> 50 ms)
    # buttons_s(0) <= '1'; wait for 2050 ms;   buttons_s(0) <= '0'; wait for 20 us;     
    
    # # Pass several generations
    # # Short center (< 50 ms)
    # buttons_s(0) <= '1'; wait for 60 ms;   buttons_s(0) <= '0'; wait for 20 us; 
    # # Short center (< 50 ms)
    # buttons_s(0) <= '1'; wait for 60 ms;   buttons_s(0) <= '0'; wait for 20 us; 
    # # Short center (< 50 ms)
    # buttons_s(0) <= '1'; wait for 60 ms;   buttons_s(0) <= '0'; wait for 20 us; 
    # # Short center (< 50 ms)
    # buttons_s(0) <= '1'; wait for 60 ms;   buttons_s(0) <= '0'; wait for 20 us;                                    

    
    
    # for _ in range(10): await RisingEdge(tb.dut.clk_i)
    # tb.dut.start_i.value = 1
    # for _ in range(8*16+20): await RisingEdge(tb.dut.clk_i) # Wait for 1/2 frame aprox
    # # Test backpressure
    # tb.dut.m_axis_tready.value = 0
    # for _ in range(10): await RisingEdge(tb.dut.clk_i)
    # # Test the rest of the frame
    # tb.dut.m_axis_tready.value = 1
    # for _ in range(8*16): await RisingEdge(tb.dut.clk_i)
    
###################################################################################
# cocotb-test flow (alternative to Makefile flow)
###################################################################################

tests_path = os.path.abspath(os.path.dirname(__file__))
rtl_dir = os.path.abspath(os.path.join(tests_path, '..', '..', '..', 'rtl'))

def test_test_game_of_life(request):
    dut = "test_game_of_life"
    module = os.path.splitext(os.path.basename(__file__))[0]
    toplevel = dut

    vhdl_sources = [
        os.path.join(rtl_dir, f"{dut}.vhd"),       
        os.path.join(rtl_dir, "board_init.vhd"),
        os.path.join(rtl_dir, "board_to_frame.vhd"),
        os.path.join(rtl_dir, "button_handler.vhd"),
        os.path.join(rtl_dir, "cells.vhd"),        
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
