# 16-bit Pipelined ALU — Verilog Design
## MTech VLSI Design Project

---

## Architecture Overview

```
                      ┌─────────────────────────────────────────────┐
                      │            16-bit Pipelined ALU             │
                      │                                             │
  i_a[15:0] ──────┐   │  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
  i_b[15:0] ──────┤   │  │ Stage 1  │  │ Stage 2  │  │ Stage 3  │   │──► o_result[31:0]
  i_opcode[4:0] ──┤──►│  │ Input    │─►│ Execute  │─►│ Output   │   │──► o_flags[3:0]
  i_valid ────────┘   │  │ Register │  │ (Comb.)  │  │ Register │   │──► o_valid
                      │  └──────────┘  └──────────┘  └──────────┘   │──► o_exception
                      └─────────────────────────────────────────────┘
                               ↑              ↑
                         Active-LOW      6 Submodules:
                         Sync Reset      adder, multiplier, divider,
                                         logic, shift, compare
```

**Pipeline Latency:** 3 clock cycles  
**Throughput:** 1 result/cycle (after warmup)  
**Clock Domain:** Single, synchronous, active-LOW reset

---

## File Structure

```
alu_project/
├── alu_pkg.vh          # Parameters, opcodes, flag definitions
├── alu_adder.v         # ADD/SUB via Carry Lookahead Adder
├── alu_multiplier.v    # MUL via Radix-2 Booth's Algorithm
├── alu_divider.v       # DIV via Restoring Division
├── alu_logic.v         # AND/OR/XOR/NOT/NAND/NOR/XNOR
├── alu_shift.v         # SLL/SRL/SRA/ROL/ROR
├── alu_compare.v       # EQ/NEQ/LT/GT/LTE/GTE (signed + unsigned)
├── alu_top.v           # Top-level pipeline integration
├── alu_tb.v            # Self-checking testbench
├── Makefile            # Build automation
└── README.md           # This file
```

---

## Opcodes Reference

| Group      | Opcode[4:0] | Operation          | Notes                        |
|------------|-------------|-------------------|------------------------------|
| Arithmetic | 5'b00_000   | ADD               | Flags: Z,N,C,OVF             |
|            | 5'b00_001   | SUB               | 2's complement               |
|            | 5'b00_010   | MUL               | 32-bit result, Booth's algo  |
|            | 5'b00_011   | DIV               | {rem,quot}, restoring div    |
|            | 5'b00_100   | ABS               | Absolute value               |
| Logical    | 5'b01_000   | AND               |                              |
|            | 5'b01_001   | OR                |                              |
|            | 5'b01_010   | XOR               |                              |
|            | 5'b01_011   | NOT               | Operates on A only           |
|            | 5'b01_100   | NAND              |                              |
|            | 5'b01_101   | NOR               |                              |
|            | 5'b01_110   | XNOR              |                              |
| Shift      | 5'b10_000   | SLL               | Shift Left Logical           |
|            | 5'b10_001   | SRL               | Shift Right Logical          |
|            | 5'b10_010   | SRA               | Shift Right Arithmetic       |
|            | 5'b10_011   | ROL               | Rotate Left                  |
|            | 5'b10_100   | ROR               | Rotate Right                 |
| Compare    | 5'b11_000   | EQ                | Result = 32'h1 or 32'h0      |
|            | 5'b11_001   | NEQ               |                              |
|            | 5'b11_010   | LT (signed)       |                              |
|            | 5'b11_011   | GT (signed)       |                              |
|            | 5'b11_100   | LTE (signed)      |                              |
|            | 5'b11_101   | GTE (signed)      |                              |
|            | 5'b11_110   | ULT (unsigned)    |                              |
|            | 5'b11_111   | UGT (unsigned)    |                              |

---

## Flags Output [3:0]

| Bit | Name     | Description                          |
|-----|----------|--------------------------------------|
| 0   | ZERO     | Result is all zeros                  |
| 1   | NEGATIVE | MSB of result is 1 (signed negative) |
| 2   | CARRY    | Carry/borrow out (arithmetic only)   |
| 3   | OVERFLOW | Signed overflow (arithmetic only)    |

---

## How to Simulate

### Icarus Verilog (free, open-source)
```bash
# Install
sudo apt install iverilog gtkwave   # Ubuntu/Debian

# Run simulation
make sim

# View waveforms
make wave
```

### ModelSim
```tcl
vlib work
vlog alu_pkg.vh alu_adder.v alu_multiplier.v alu_divider.v \
     alu_logic.v alu_shift.v alu_compare.v alu_top.v alu_tb.v
vsim alu_tb
run -all
```

---

## Synthesis Notes (FPGA / ASIC)

- The divider is purely combinational and will be the **critical path**. For
  timing closure above ~100 MHz, replace with a multi-cycle FSM (see TODO in
  `alu_divider.v`).
- The multiplier's Booth partial products synthesise efficiently on FPGA DSP
  blocks (Xilinx DSP48, Intel DSP blocks). Let the synthesiser infer them via
  `*` rather than forcing the Booth structure if targeting FPGA.
- Use `KEEP_HIERARCHY` / `dont_touch` constraints on pipeline registers to
  prevent optimisation across stage boundaries.
- Instantiate flip-flops with `(*clock_enable*)` attribute on `s1_valid` and
  `s2_valid` for power gating when idle.

---

## Possible Extensions

1. **Forwarding / Bypass** — Add data forwarding to eliminate read-after-write hazards
2. **Saturation arithmetic** — Clamp to MAX/MIN instead of wrapping on overflow  
3. **Floating point** — Extend with IEEE-754 half-precision (16-bit) unit
4. **AXI-Lite interface** — Wrap with AXI-Lite for SoC integration
5. **Multi-cycle division FSM** — Replace combinational divider with handshaked FSM
6. **UVM Testbench** — Replace directed TB with UVM agent for functional coverage
