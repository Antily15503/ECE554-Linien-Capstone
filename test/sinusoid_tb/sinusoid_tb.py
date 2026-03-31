import random
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotb.triggers import RisingEdge
from cocotb.triggers import FallingEdge
from cocotb.triggers import Timer
from cocotb.triggers import First

#method to load in values into the DUT. 
async def load(dut,address,data):
    dut.i_param_addr.value=address
    dut.i_param_data.value=data
    dut.i_en.value=1
    dut.i_wren.value=1
    await RisingEdge(dut.clk)

    #after rising edge, de-assert
    dut.i_en.value=0
    dut.i_wren.value=0
    pass

@cocotb.test()
async def test1(dut):
    cocotb.log.info("test 1")
    dut.rst_n.value=0
    dut.i_en.value=0
    dut.i_wren.value=0
    dut.i_start.value=0
    #clock period should be 8ns, equivalent to 125 mHz
    clock=Clock(dut.clk,8,unit='ns')

    start_clock=cocotb.start_soon(clock.start())
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value=1
    await ClockCycles(dut.clk, 2)

    await load(dut,0,1000)
    await ClockCycles(dut.clk, 2)
    await load(dut,1,2**12)
    await ClockCycles(dut.clk, 2)
    await load(dut,2,-(2**15))
    await ClockCycles(dut.clk, 2)
    await load(dut,3,2**15)
    await ClockCycles(dut.clk, 2)
    await load(dut,4,1000000)
    await ClockCycles(dut.clk, 2)
    await load(dut,5,2**15)
    dut.i_en.value=1
    dut.i_start.value=1
    await ClockCycles(dut.clk, 2)
    dut.i_en.value=0
    dut.i_start.value=0
    await ClockCycles(dut.clk, 100000)

    await load(dut,0,2000)
    await ClockCycles(dut.clk, 2)
    await load(dut,1,2**13)
    await ClockCycles(dut.clk, 2)
    await load(dut,2,-(2**11))
    await ClockCycles(dut.clk, 2)
    await load(dut,3,2**12)
    await ClockCycles(dut.clk, 2)
    await load(dut,4,1000000)
    await ClockCycles(dut.clk, 2)
    await load(dut,5,2**11)
    dut.i_en.value=1
    dut.i_start.value=1
    await ClockCycles(dut.clk, 2)
    dut.i_en.value=0
    dut.i_start.value=0
    await ClockCycles(dut.clk, 100000)
    pass
