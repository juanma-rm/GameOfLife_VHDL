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
from cocotbext.axi import (AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor)

###################################################################################
# TB class (common for all tests)
###################################################################################

class TB:

    key_mapping = {
        'esc'       : 0,
        'up'        : 1,
        'down'      : 2,
        'left'      : 3,
        'right'     : 4,
        'space'     : 5,
        'c'         : 6,
        'enter'     : 7,
        'backspace' : 8
    }

    def __init__(self, dut):
        self.dut = dut

        self.log = SimLog("cocotb.tb")
        self.log.setLevel(logging.DEBUG)

        cocotb.start_soon(Clock(dut.clk_i, 1000, units="ns").start())
        
        self.s_axis_keyboard = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.clk_i, dut.rst_i)
        self.m_axis_video = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.clk_i, dut.rst_i)

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

    # To visualise changes w/o long simulations, set the constants in game_of_life.vhd as following:
    # constant one_s_max_c : integer := 100;
    # constant refresh_ticks_c  : integer := 100;
   
    # Initialise the board by toggling the first row (expected to have 4 pixels)
    await Timer(4000, units='ns')
    for col in range(4):
        await tb.s_axis_keyboard.send(tb.key_mapping['space'].to_bytes(4, byteorder='little'))
        await tb.s_axis_keyboard.wait()
        await tb.s_axis_keyboard.send(tb.key_mapping['right'].to_bytes(4, byteorder='little'))
        await tb.s_axis_keyboard.wait()
    await Timer(4000, units='ns')
    
    # Confirm board state by pressing enter
    await tb.s_axis_keyboard.send(tb.key_mapping['enter'].to_bytes(4, byteorder='little'))
    await tb.s_axis_keyboard.wait()
    await Timer(4000, units='ns')
    
    # Toggle continuous mode (enabling it)
    await tb.s_axis_keyboard.send(tb.key_mapping['c'].to_bytes(4, byteorder='little'))
    await tb.s_axis_keyboard.wait()
    await Timer(10000, units='ns')    

    # Let cells evolve in continuous mode
    await tb.s_axis_keyboard.send(tb.key_mapping['space'].to_bytes(4, byteorder='little'))
    await tb.s_axis_keyboard.wait()
    # Wait for 10 generations (2 rows 4 cols per each data received at m_axis_video)
    for generation in range(10*2*4):
        data = await tb.m_axis_video.recv()
        print(data.tdata)
    
    # Back to initialisation stage
    await tb.s_axis_keyboard.send(tb.key_mapping['backspace'].to_bytes(4, byteorder='little'))
    await tb.s_axis_keyboard.wait()
    await Timer(10000, units='ns')
    
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
