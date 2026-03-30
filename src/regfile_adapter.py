"""
regfile_adapter.py - bridges linien's CSR bus to our reg_file

the PS (arm cpu) can't talk to reg_file.sv directly because reg_file
is just a plain BRAM with no CSR interface. so this module sits in
between and translates CSR writes into reg_file port A writes.

how it works:
  1. PS writes an address to wr_addr
  2. PS writes data to wr_data
  3. PS writes 1 to wr_strobe
  4. adapter catches the 0->1 edge and pulses wr_en for exactly 1 cycle
  5. reg_file latches the write on that clock edge

also passes through num_blocks (goes to control.sv i_num_blocks) and
enable (goes to ttl_handler.i_enable) since those don't need to go
through reg_file, they're just standalone config values.

goes into csr_map as bank 9. auto-generated register names will be
regfile_adapter_wr_addr, regfile_adapter_wr_data, etc in csrmap.py.
"""

from migen import *
from misoc.interconnect.csr import AutoCSR, CSRStorage, CSRStatus

class RegFileAdapter(Module, AutoCSR):
    def __init__(self, regfile):
        # CSR registers (PS-facing)
        self.wr_addr = CSRStorage(8, name="wr_addr")  # which reg to write
        self.wr_data = CSRStorage(32, name="wr_data")  # value to write
        self.wr_strobe = CSRStorage(name="wr_strobe")  # pulse to write

        self.num_blocks = CSRStorage(4, name="num_blocks")  # how many blocks in the sequence
        self.enable = CSRStorage(1, name="enable")  # pulse to start the sequence

        # Outputs to the regfile
        self.o_wr_addr = Signal(8, name="o_wr_addr")
        self.o_wr_data = Signal(32, name="o_wr_data")
        self.o_wr_en = Signal(name="o_wr_en")

        self.o_num_blocks = Signal(4, name="o_num_blocks")
        self.o_enable = Signal(name="o_enable")

        # write pulse logic
        strobe_prev = Signal()
        self.sync += strobe_prev.eq(self.wr_strobe.storage)

        self.comb += [
            self.o_wr_addr.eq(self.wr_addr.storage),
            self.o_wr_data.eq(self.wr_data.storage),
            self.o_wr_en.eq(self.wr_strobe.storage & ~strobe_prev),
            self.o_num_blocks.eq(self.num_blocks.storage),
            self.o_enable.eq(self.enable.storage)
        ]