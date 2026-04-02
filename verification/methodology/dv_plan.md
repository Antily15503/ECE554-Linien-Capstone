# Design Verification Plan — ECE554 Linien Capstone
**Design Under Verification:** `sequence_top` (TTL-triggered waveform sequencer for Linien spectroscopy)  
**Document Date:** 2026-04-02  
**Methodology Version:** 1.0

---

## 1. Overview

### 1.1 Design Intent

`sequence_top` is a programmable waveform sequencer. An ARM processor writes a sequence of "blocks" (delay, linear_ramp, direct_jump, chirp, sinusoid, arb_wave) into a dual-port BRAM register file. On a TTL trigger (`i_start`), the control FSM reads and executes each block in order, driving a 14-bit DAC output (`o_dac_drive`). When the sequence completes, `o_seq_done` pulses for one cycle.

### 1.2 Verification Goals

| Goal | Metric |
|---|---|
| All block types produce correct DAC output | Per-block output golden model match |
| Control FSM executes all state transitions correctly | 100% state reachability |
| Parameter bus correctly delivers params to each block type | All param addresses exercised |
| No X/Z propagation on DAC output during active sequences | Signal integrity check |
| Correct behavior on reset (sync and async paths) | Reset assertion at every FSM state |
| No rogue behavior on unexpected input combinations | Boundary & adversarial testing |
| Race condition freedom | Verified via nonblocking-assignment discipline + CDC checks |

---

## 2. Verification Environment Architecture

The testbench environment is modular: each sub-block has its own isolated testbench, and a top-level integration testbench exercises the fully assembled `sequence_top`.

```
verification/
├── reports/
│   └── code_review.md       ← static lint and logic issues (read first)
├── methodology/
│   └── dv_plan.md           ← this document
└── tb/
    ├── tb_delay.sv          ← Block 0 isolated test
    ├── tb_direct_jump.sv    ← Block 2 isolated test
    ├── tb_linear_ramp.sv    ← Block 1 isolated test
    ├── tb_chirp_gen.sv      ← Block 3 isolated test
    ├── tb_arb_wave.sv       ← Block 5 isolated test (with BRAM mock)
    ├── tb_control.sv        ← FSM test with inline register file model
    └── tb_sequence_top.sv   ← Full integration test
```

### 2.1 Prerequisite: Fix Compile Errors First

The following source issues (documented in `reports/code_review.md`) **must be fixed before any TB can compile**:

1. `bram.sv`: change `module reg_file` → `module bram`
2. `top.sv:197`: remove `assign block_drive[5] = 14'b0;`
3. `top.sv:184`: remove `#(.DATA_WIDTH(DATA_WIDTH))` from sinusoid instantiation
4. `chirp_gen_tb.sv`: this existing TB is replaced by `tb_chirp_gen.sv` in the `verification/tb/` folder

### 2.2 Toolchain

**Primary simulator:** Icarus Verilog (iverilog) — free, cross-platform, supports SV 2012.

**Compile command for block-level TBs:**
```bash
iverilog -g2012 -Wall \
    -o sim_out \
    src/<dut>.sv \
    verification/tb/tb_<dut>.sv
vvp sim_out
```

**Compile command for integration TB:**
```bash
iverilog -g2012 -Wall \
    -o sim_top \
    src/bram.sv src/control.sv src/delay.sv src/linear_ramp.sv \
    src/direct_jump.sv src/chirp_gen.sv src/sinusoid.sv src/arb_wave.sv \
    src/top.sv \
    verification/tb/tb_sequence_top.sv
vvp sim_top
```

**Note for sinusoid:** The `sinusoid` module uses `$readmemh("sin_lut.memh", sin_LUT)`. The `sin_lut.memh` file must be present in the working directory when simulating any TB that includes sinusoid.

**Waveform viewing:** GTKWave — open the `.vcd` output from any TB.
```bash
gtkwave dump.vcd &
```

---

## 3. Lint-First Policy

**Before running any simulation, perform a static lint pass** using the rules in `sv-test/references/lint-rules.md`. The current status is in `reports/code_review.md`. Do not advance to simulation until all `COMPILE ERROR` and `LINT ERROR` items are resolved.

**Quick lint check command (verilator):**
```bash
verilator --lint-only -Wall --timing src/<file>.sv
```

---

## 4. Block-Level Verification Plans

Each block TB follows this standard structure:
1. **Reset test** — assert rst_n=0, verify all outputs are 0
2. **Param load test** — drive en=1 with each valid param address, verify params are latched
3. **Nominal operation** — assert active, verify expected output sequence
4. **Boundary conditions** — zero/max/negative parameter values
5. **Inactive override** — verify output returns to 0 when active deasserts mid-operation
6. **Adversarial/race** — param write while active; simultaneous en and active

---

### 4.1 Delay Block (`delay.sv`) — Block Type 0

**DUT interface:**
- Inputs: `clk`, `rst_n`, `en`, `i_param_data[31:0]`, `i_param_addr[3:0]`, `active`
- Outputs: `v_drive[13:0]`

**Parameters:**
| param_addr | Meaning |
|---|---|
| 0 | `v_prev` — hold voltage while active |

**Test cases:**

| TC | Stimulus | Expected Result | Race/Rogue Check |
|---|---|---|---|
| TC-D1 | Reset assertion | `v_drive == 0` | — |
| TC-D2 | Load v_prev=512, active=1 | `v_drive == 14'd512` | — |
| TC-D3 | active=0 | `v_drive == 0` | — |
| TC-D4 | v_prev=0, active=1 | `v_drive == 0` | Zero-drive check |
| TC-D5 | v_prev=max(14'h3FFF), active=1 | `v_drive == 14'h3FFF` | Max-value check |
| TC-D6 | Write to invalid param_addr=1 while en=1 | `v_drive` unchanged | Addr decode check |
| TC-D7 | Reset asserted while active=1 | `v_drive == 0` | Async reset mid-operation |
| TC-D8 | Param write (en=1) while active=1 | Param updates live | Write-while-active race |

---

### 4.2 Direct Jump Block (`direct_jump.sv`) — Block Type 2

**DUT interface:** identical structure to delay.

**Test cases:** Mirror TC-D1 through TC-D8 (logic is identical to delay per module comment).

Additional test:

| TC | Stimulus | Expected Result |
|---|---|---|
| TC-J9 | i_param_data[31:14] has noise bits | Only bits [13:0] captured in v_target |

---

### 4.3 Linear Ramp Block (`linear_ramp.sv`) — Block Type 1

**Parameters:**
| param_addr | Meaning |
|---|---|
| 0 | `v_start` — initial voltage |
| 1 | `v_step` — signed increment per cycle |

**Test cases:**

| TC | Stimulus | Expected Result | Notes |
|---|---|---|---|
| TC-LR1 | Reset | `v_drive == 0` | — |
| TC-LR2 | Load v_start=100, v_step=5; active for 10 cycles | Output = 100,105,110,...,145 | Sample all 10 values |
| TC-LR3 | Negative step: v_start=500, v_step=-10 | Output decrements by 10 each cycle | — |
| TC-LR4 | Deassert active mid-ramp | `v_drive == 0` immediately | No latency |
| TC-LR5 | Reassert active | Starts again from v_start (new active_pulse) | Re-trigger check |
| TC-LR6 | v_step=0 | Output holds at v_start forever | Zero-step |
| TC-LR7 | Overflow test: v_start=8100, v_step=500 | **KNOWN BUG** — wraps at ±8192 boundary | Document wrap |
| TC-LR8 | Reset mid-ramp | Output clears to 0 | — |

---

### 4.4 Chirp Generator (`chirp_gen.sv`) — Block Type 3

**Parameters:**
| param_addr | Meaning |
|---|---|
| 0 | `a` — initial voltage (signed 32-bit) |
| 1 | `b` — (currently unused by FSM — see Issue 28) |
| 2 | `rate` — initial frequency rate |
| 3 | `raterate` — rate of change of rate (chirp coefficient) |

**Test cases:**

| TC | Stimulus | Expected Result | Notes |
|---|---|---|---|
| TC-C1 | Reset | `voltage == 0` | — |
| TC-C2 | Params: a=0, rate=10, raterate=1; active for 20 cycles | Output follows parabolic profile | Verify each cycle |
| TC-C3 | active deasserts | `voltage == 0` | — |
| TC-C4 | Clamp high: a=8000, rate=500, raterate=100 | `voltage` clamps at `14'sh1FFF` (8191) | Verify no overflow |
| TC-C5 | Clamp low: a=-8000, rate=-500, raterate=-100 | `voltage` clamps at `-14'sh2000` (-8192) | Verify no underflow |
| TC-C6 | Rising edge of active re-loads a | Starting from previous active | Re-trigger check |
| TC-C7 | Params written while active=1 | DUT ignores (en=0 during active) | Invariant check |
| TC-C8 | Reset mid-execution | All registers clear, voltage=0 | Async reset safety |

---

### 4.5 Arb Wave Block (`arb_wave.sv`) — Block Type 5

**Parameters:**
| param_addr | Meaning |
|---|---|
| 0 | `clk_div` — BRAM address increment period |

**Test cases:**

| TC | Stimulus | Expected Result | Notes |
|---|---|---|---|
| TC-A1 | Reset | `o_drive == 0`, `o_bram_addr == 0` | — |
| TC-A2 | clk_div=1; active; mock BRAM returning sequential values | `o_drive` follows BRAM output with 1-cycle latency | — |
| TC-A3 | clk_div=4; active for 40 cycles | Address advances every 4 cycles | Verify div_counter |
| TC-A4 | BRAM address wraps at 1023 | Address saturates at 1023, does not wrap to 0 | **Verify saturation behavior** |
| TC-A5 | Deassert active | `o_drive == 0`, addr resets to 0 | — |
| TC-A6 | clk_div=0 | Edge case: divider off-by-one (clk_div-1 = all-ones) | Underflow risk |
| TC-A7 | clk_div=1 (default reset value) | Increments every cycle | Default value check |
| TC-A8 | `active_pulse` monitoring | Currently unused — verify no glitch side effect | Dead code check |

---

### 4.6 Sinusoid Block (`sinusoid.sv`) — Block Type 4

**Note:** Sinusoid requires `sin_lut.memh` in the simulator working directory.  
**Note:** `o_done` / `run_time` is dead in top-level integration (see Issue 15). Testbench tests it in isolation.

**Parameters:**
| param_addr | Meaning |
|---|---|
| 0 | `v_mid` — DC offset |
| 1 | `v_amp` — amplitude scale |
| 2 | `v_min_cut` — lower clamp |
| 3 | `v_max_cut` — upper clamp |
| 4 | `phase_increment` — NCO step |

**Test cases:**

| TC | Stimulus | Expected Result | Notes |
|---|---|---|---|
| TC-S1 | Reset | All params=0, `o_drive=0` | — |
| TC-S2 | Load params; assert i_start (active_pulse) | `o_drive` follows LUT with scaling and DC offset | Verify a few key phase points |
| TC-S3 | v_min_cut / v_max_cut clamping | Output never exceeds cutoff values | Boundary test |
| TC-S4 | v_amp=0 | `o_drive == v_mid` constantly | Zero amplitude |
| TC-S5 | Large phase_increment | Faster traversal of LUT | Coarse sinusoid |
| TC-S6 | Param write while in WORK state | Params locked (state check in param-load logic) | Invariant |
| TC-S7 | Reset during WORK | Returns to IDLE, output = 0 | — |
| TC-S8 | run_time isolation | `o_done` fires at correct internal timer value (isolated TB) | Dead in top-level |

---

## 5. Control FSM Verification Plan (`control.sv`)

The control FSM is the most complex block and warrants dedicated white-box testing.

### 5.1 State Reachability

Every FSM state must be visited in at least one test:

| State | Triggered By |
|---|---|
| `IDLE` | Reset, or return from `DONE` |
| `FETCH_TYPE` | `i_start` pulse |
| `LOAD_INIT` | Always from `FETCH_TYPE` |
| `LOAD_PARAMS` | Always from `LOAD_INIT` |
| `START_BLOCK` | `last_param` reached in `LOAD_PARAMS` |
| `WAIT_DONE` | Always from `START_BLOCK` |
| `CAPTURE_VDRIVE` | `timer_flag` (count >= dur) |
| `DONE` | `last_block` in `CAPTURE_VDRIVE` |

### 5.2 FSM Test Cases

| TC | Scenario | Expected Behavior |
|---|---|---|
| TC-FSM1 | Single delay block (i_num_blocks=0) | Full state sequence, o_seq_done pulses once |
| TC-FSM2 | Two-block sequence (delay + linear_ramp) | Two full cycles, seq_done pulses after block 1 |
| TC-FSM3 | All 6 block types in sequence | Each type receives correct param_addr/param_data |
| TC-FSM4 | i_start while already active | FSM stays in current state (i_start ignored outside IDLE) |
| TC-FSM5 | Reset in WAIT_DONE state | Returns to IDLE, outputs cleared |
| TC-FSM6 | Reset in LOAD_PARAMS state | Returns to IDLE cleanly |
| TC-FSM7 | duration=1 (minimum timer) | Transitions WAIT_DONE→CAPTURE_VDRIVE after 1 cycle |
| TC-FSM8 | duration=0 | `timer_flag = (count >= 0)` — always true; verify graceful handling |
| TC-FSM9 | 16 blocks (i_num_blocks=15, max) | All 16 executed; seq_done fires after last |
| TC-FSM10 | Verify o_block_en is zero in START_BLOCK | No param bus activity during execution |
| TC-FSM11 | Verify prev_v_drive holds across blocks | DAC output does not glitch between blocks |
| TC-FSM12 | CAPTURE_VDRIVE captures active block drive | i_block_drive[cur_type] stored in prev_v_drive |

### 5.3 Parameter Bus Timing Verification

The parameter bus is a critical shared interface. Verify:

1. `o_param_addr` starts at 0 for the first param each block.
2. `o_block_en[type]` is only high during LOAD_PARAMS (not during START_BLOCK or WAIT_DONE).
3. `o_block_active[type]` is only high during START_BLOCK, WAIT_DONE, and CAPTURE_VDRIVE.
4. `o_param_data` is valid (`i_regfile_data`) in the same cycle `o_block_en` is high.
5. Exactly one bit of `o_block_en` is ever high (one-hot enforcement).

---

## 6. Integration Test Plan (`tb_sequence_top.sv`)

The top-level integration TB tests the full path: register file write → control FSM → block parameter load → execution → DAC output.

### 6.1 Integration Test Cases

| TC | Scenario | Verified Signals |
|---|---|---|
| TC-INT1 | Reset and idle state | All outputs 0, o_active=0, o_seq_done=0 |
| TC-INT2 | Single delay block: hold 1000 for 20 cycles | o_dac_drive=1000 during block, o_seq_done pulses at end |
| TC-INT3 | Delay → Linear Ramp sequence | DAC shows constant then ramping output |
| TC-INT4 | Direct Jump: jump to 2000 | DAC immediately reflects 2000 |
| TC-INT5 | Chirp block with observable parabolic ramp | DAC output verified against golden model |
| TC-INT6 | AWG block with pre-loaded BRAM data | DAC follows BRAM content |
| TC-INT7 | o_active timing: high from FETCH_TYPE through CAPTURE_VDRIVE | Verify with waveform |
| TC-INT8 | o_seq_done is exactly 1 cycle wide | Check rising and falling edges |
| TC-INT9 | Back-to-back starts (i_start immediately after o_seq_done) | Second sequence starts correctly |
| TC-INT10 | Reset mid-sequence | All outputs clear; FSM returns to IDLE |

---

## 7. Race Condition and Rogue Behavior Detection

### 7.1 Known Race Risks

| Location | Risk | Detection Strategy |
|---|---|---|
| `block_drive[5]` in top.sv | Multiple driver (see Issue 1) | Compile error + code review |
| Control FSM `o_block_en` timing | If en pulses overlap with active, block may accept spurious params | TC-FSM10 + `o_block_en & o_block_active` concurrent assertion |
| `i_start` during active sequence | FSM ignores it — verify no state corruption | TC-FSM4 |
| sinusoid param write during WORK state | Params locked by `curr_state == IDLE` guard | TC-S6 |
| arb_wave `div_counter` when `i_active` toggles | Counter resets on deassert — verify no addr corruption | TC-A5 |
| linear_ramp overflow | Silent wrap when step accumulates past ±8191 | TC-LR7 (document expected wrap) |
| BRAM simultaneous read/write | Same address on both ports in same cycle | Add to integration TC |

### 7.2 Rogue Behavior Checklist

For every TB, check that the following conditions **never** produce undefined (X/Z) output:
- Immediately after reset deasserts
- When en=0 and active=0 simultaneously
- When all inputs are zero
- When i_start is held high for multiple cycles (not just a pulse)

### 7.3 Signal Integrity Rules

1. `o_dac_drive` must never be X/Z during an active sequence (use `$fatal` assertion in TB).
2. `o_seq_done` must be exactly 1 cycle wide, never stuck high.
3. `o_block_en` and `o_block_active` must be mutually timed (en precedes active, they don't overlap for the same block in the same cycle).
4. `o_active` must be high for the entire duration from `FETCH_TYPE` through `CAPTURE_VDRIVE`.

### 7.4 Concurrency and Clocking Rules

All sequential blocks use `posedge clk` with active-low reset. No CDC crossings exist within this design (single clock domain). Primary race risks are:

- **Assignment race in simulation:** All TBs must drive inputs after a `#1` delay (or on `negedge clk`) to avoid setup time violations in simulation.
- **Nonblocking assignment discipline:** All `always_ff` blocks must use `<=`. Any blocking `=` in an `always_ff` is a SNUG-1 violation that can cause sim/synth mismatch.
- **Multiple drivers:** Resolved by code review Issue 1 fix.

---

## 8. Signal Tracing Methodology

### 8.1 VCD Dump — Every TB

Every testbench includes:
```sv
initial begin
    $dumpfile("tb_<name>.vcd");
    $dumpvars(0, tb_<name>);
end
```

Waveforms are opened with GTKWave. Key signals to always include:
- `clk`, `rst_n`
- All DUT inputs/outputs
- Internal state registers (especially FSM state in `tb_control`)
- `o_seq_done`, `o_active` (integration TB)

### 8.2 Standard Signal Grouping for GTKWave

Create a GTKWave save file grouping signals as:
1. **Clock/Reset** group: `clk`, `rst_n`
2. **Control Bus** group: `i_start`, `o_block_en`, `o_block_active`, `o_param_addr`, `o_param_data`
3. **DAC Output** group: `o_dac_drive`, `o_seq_done`, `o_active`
4. **Block internals** group: per-block internal state/registers

### 8.3 Failure Root Cause Classification

When a test fails, use this flowchart:

```
Output X/Z? → Uninitialized signal, undriven port, or multiple driver issue
Output stuck 0? → Check active/en signal path; check reset deassert
Output wrong value? → Trace param bus; verify register file contents
Output one cycle late? → Sync read latency; check pipeline stage
FSM stuck? → Check timer_flag; verify dur was loaded; check last_param logic
Seq never done? → Verify i_num_blocks value; check CAPTURE_VDRIVE last_block condition
```

---

## 9. Coverage Goals

| Coverage Type | Target | Measured By |
|---|---|---|
| FSM state coverage | 100% of 8 states hit | Manual via `$display` or VCD |
| FSM transition coverage | 100% of defined arcs | Trace state register in VCD |
| Param address coverage | All valid param addresses exercised per block | TB checklist |
| Block type activation | All 6 block types activated in integration TB | TC-INT checklist |
| Reset assertion | Reset asserted at every FSM state | TC-FSM5, TC-FSM6 |
| Boundary values | 0, 1, max-1, max for all DATA_WIDTH fields | Per-block TCs |

---

## 10. Regression Strategy

Run the full regression in this order:

```
1. Static lint (verilator --lint-only) for each src file
2. tb_delay.sv         → "PASS: delay block"
3. tb_direct_jump.sv   → "PASS: direct_jump block"
4. tb_linear_ramp.sv   → "PASS: linear_ramp block"
5. tb_chirp_gen.sv     → "PASS: chirp_gen block"
6. tb_arb_wave.sv      → "PASS: arb_wave block"
7. tb_control.sv       → "PASS: control FSM"
8. tb_sequence_top.sv  → "PASS: integration"
```

All TBs use `$display("PASS: ...")` on success and `$fatal(...)` on failure, making automated pass/fail detection trivial with a grep on stdout.
