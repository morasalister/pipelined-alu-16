//=============================================================================
// File        : alu_pkg.vh
// Project     : 16-bit Pipelined ALU
// Author      : MTech VLSI Design Project
// Description : Global parameters, opcodes, and macro definitions.
//               Include this file in every module with `include "alu_pkg.vh"
//
// Coding Style: Industry-standard synthesisable Verilog-2001
//=============================================================================

`ifndef ALU_PKG_VH
`define ALU_PKG_VH

// -------------------------------------------------------------------------
// Data width parameters — change DATA_WIDTH here to retarget the entire ALU
// -------------------------------------------------------------------------
`define DATA_WIDTH      16
`define OPCODE_WIDTH     5   // 5 bits => 32 opcodes max
`define RESULT_WIDTH    32   // MUL produces 2x width

// -------------------------------------------------------------------------
// Pipeline depth
// -------------------------------------------------------------------------
`define PIPE_STAGES      3   // Stage1:InputReg  Stage2:Execute  Stage3:OutputReg

// -------------------------------------------------------------------------
// ALU Opcodes  [4:0]
// Group        Bits[4:3]   Individual Op    Bits[2:0]
// -------------------------------------------------------------------------
//  Arithmetic   2'b00
`define OP_ADD   5'b00_000   // A + B
`define OP_SUB   5'b00_001   // A - B
`define OP_MUL   5'b00_010   // A * B  (32-bit result)
`define OP_DIV   5'b00_011   // A / B  (quotient in result[15:0], remainder in result[31:16])
`define OP_ABS   5'b00_100   // |A|

//  Logical      2'b01
`define OP_AND   5'b01_000   // A & B
`define OP_OR    5'b01_001   // A | B
`define OP_XOR   5'b01_010   // A ^ B
`define OP_NOT   5'b01_011   // ~A
`define OP_NAND  5'b01_100   // ~(A & B)
`define OP_NOR   5'b01_101   // ~(A | B)
`define OP_XNOR  5'b01_110   // ~(A ^ B)

//  Shift        2'b10
`define OP_SLL   5'b10_000   // Shift Left  Logical   A << B[3:0]
`define OP_SRL   5'b10_001   // Shift Right Logical   A >> B[3:0]
`define OP_SRA   5'b10_010   // Shift Right Arithmetic A >>> B[3:0]
`define OP_ROL   5'b10_011   // Rotate Left
`define OP_ROR   5'b10_100   // Rotate Right

//  Comparison   2'b11
`define OP_EQ    5'b11_000   // A == B  → result = 32'b1 or 32'b0
`define OP_NEQ   5'b11_001   // A != B
`define OP_LT    5'b11_010   // A <  B  (signed)
`define OP_GT    5'b11_011   // A >  B  (signed)
`define OP_LTE   5'b11_100   // A <= B  (signed)
`define OP_GTE   5'b11_101   // A >= B  (signed)
`define OP_ULT   5'b11_110   // A <  B  (unsigned)
`define OP_UGT   5'b11_111   // A >  B  (unsigned)

// -------------------------------------------------------------------------
// Flag bit positions in the flags output bus [3:0]
// -------------------------------------------------------------------------
`define FLAG_ZERO     0   // Result is zero
`define FLAG_NEGATIVE 1   // MSB of result is 1 (signed negative)
`define FLAG_CARRY    2   // Carry/borrow out from bit 15
`define FLAG_OVERFLOW 3   // Signed overflow

// -------------------------------------------------------------------------
// Error / Exception codes in result[31:28] when DIV_BY_ZERO etc.
// -------------------------------------------------------------------------
`define EXC_NONE      4'b0000
`define EXC_DIV_ZERO  4'b0001
`define EXC_OVERFLOW  4'b0010

`endif // ALU_PKG_VH
