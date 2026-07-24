//=============================================================================
// File        : alu_pkg.vh
// Project     : 16-bit Pipelined ALU
// Description : Global parameters, opcodes, and macro definitions.
//
// Change log  : Removed alu_compare module. Compare ops now reuse the adder
//               (A - B) and derive true/false from the resulting flags.
//               o_result is forced to 32'h0 for compare ops; caller reads
//               o_flags and o_cmp_true instead.
//=============================================================================

`ifndef ALU_PKG_VH
`define ALU_PKG_VH

// -------------------------------------------------------------------------
// Data width parameters
// -------------------------------------------------------------------------
`define DATA_WIDTH      16
`define OPCODE_WIDTH     5
`define RESULT_WIDTH    32

// -------------------------------------------------------------------------
// Pipeline depth
// -------------------------------------------------------------------------
`define PIPE_STAGES      3

// -------------------------------------------------------------------------
// ALU Opcodes  [4:0]
// -------------------------------------------------------------------------
//  Arithmetic   2'b00
`define OP_ADD   5'b00_000   // A + B
`define OP_SUB   5'b00_001   // A - B
`define OP_MUL   5'b00_010   // A * B  (32-bit result)
`define OP_DIV   5'b00_011   // A / B
`define OP_ABS   5'b00_100   // |A|
`define OP_ADC   5'b00_101   // A + B + carry_in
`define OP_SBC   5'b00_110   // A - B + carry_in

//  Logical      2'b01
`define OP_AND   5'b01_000
`define OP_OR    5'b01_001
`define OP_XOR   5'b01_010
`define OP_NOT   5'b01_011
`define OP_NAND  5'b01_100
`define OP_NOR   5'b01_101
`define OP_XNOR  5'b01_110

//  Shift        2'b10
`define OP_SLL   5'b10_000
`define OP_SRL   5'b10_001
`define OP_SRA   5'b10_010
`define OP_ROL   5'b10_011
`define OP_ROR   5'b10_100

//  Compare      2'b11
//  These reuse the adder subtraction path.
//  Result bus is 32'h0; truth value is on o_cmp_true output.
//  Internal: computes A - B, then decodes flags.
`define OP_EQ    5'b11_000   // A == B  →  Zero
`define OP_NEQ   5'b11_001   // A != B  → ~Zero
`define OP_LT    5'b11_010   // A <  B signed   → Negative ^ Overflow
`define OP_GT    5'b11_011   // A >  B signed   → ~Zero & ~(Negative ^ Overflow)
`define OP_LTE   5'b11_100   // A <= B signed   →  Zero |  (Negative ^ Overflow)
`define OP_GTE   5'b11_101   // A >= B signed   → ~(Negative ^ Overflow)
`define OP_ULT   5'b11_110   // A <  B unsigned →  Carry
`define OP_UGT   5'b11_111   // A >  B unsigned → ~Carry & ~Zero

// -------------------------------------------------------------------------
// Flag bit positions in o_flags [3:0]
// -------------------------------------------------------------------------
`define FLAG_ZERO     0
`define FLAG_NEGATIVE 1
`define FLAG_CARRY    2
`define FLAG_OVERFLOW 3

// -------------------------------------------------------------------------
// Exception codes
// -------------------------------------------------------------------------
`define EXC_NONE      4'b0000
`define EXC_DIV_ZERO  4'b0001
`define EXC_OVERFLOW  4'b0010

`endif // ALU_PKG_VH
