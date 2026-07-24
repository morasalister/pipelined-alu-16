`timescale 1ns/1ps
//=============================================================================
// File        : alu_top.v
// Project     : 16-bit Pipelined ALU
// Author      : Alister Moras
//
// Description : Top-level 3-stage pipelined 16-bit ALU.
//
//   ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
//   │  STAGE 1     │    │  STAGE 2     │    │  STAGE 3     │
//   │  Input Reg   │───▶│  Execute     │───▶│  Output Reg  │
//   │  (flop A,B,  │    │  (all units  │    │  (flop result│
//   │   opcode)    │    │   active,    │    │   + flags)   │
//   │              │    │   mux select)│    │              │
//   └──────────────┘    └──────────────┘    └──────────────┘
//
//   Throughput : 1 result per clock cycle (after 3-cycle initial latency)
//   Clock      : Single clock domain, synchronous active-high reset
//
// Port List:
//   i_clk        : System clock
//   i_rst_n      : Synchronous active-LOW reset (industry standard)
//   i_valid      : Input data is valid this cycle
//   i_opcode     : ALU operation select [4:0]
//   i_a, i_b     : 16-bit operands
//   o_result     : 32-bit result (full precision for MUL/DIV)
//   o_flags      : {overflow, carry, negative, zero}
//   o_valid      : Output result is valid (accounts for pipeline latency)
//   o_exception  : Exception flag (div by zero etc.)
//
// Synthesis   : Fully synthesisable Verilog-2001
//=============================================================================

`include "alu_pkg.vh"

module alu_top #(
    parameter WIDTH = `DATA_WIDTH
)(
    input  wire                       i_clk,
    input  wire                       i_rst_n,      // Active-LOW synchronous reset

    // Input interface
    input  wire                       i_valid,
    input  wire [`OPCODE_WIDTH-1:0]  i_opcode,
    input  wire [WIDTH-1:0]           i_a,
    input  wire [WIDTH-1:0]           i_b,

    // Output interface
    output reg  [2*WIDTH-1:0]         o_result,
    output reg  [3:0]                 o_flags,      // [3]=OVF [2]=CRY [1]=NEG [0]=ZERO
    output reg                        o_valid,
    output reg                        o_exception
);

    // =========================================================================
    // STAGE 1 — Input Pipeline Registers
    // =========================================================================
    reg                       s1_valid;
    reg [`OPCODE_WIDTH-1:0]  s1_opcode;
    reg [WIDTH-1:0]           s1_a;
    reg [WIDTH-1:0]           s1_b;

    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            s1_valid  <= 1'b0;
            s1_opcode <= {`OPCODE_WIDTH{1'b0}};
            s1_a      <= {WIDTH{1'b0}};
            s1_b      <= {WIDTH{1'b0}};
        end else begin
            s1_valid  <= i_valid;
            s1_opcode <= i_opcode;
            s1_a      <= i_a;
            s1_b      <= i_b;
        end
    end

    // =========================================================================
    // STAGE 2 — Execute (combinational submodules)
    // =========================================================================

    // --- Arithmetic unit (ADD/SUB) ---
    wire [WIDTH-1:0]    add_result;
    wire                add_carry, add_ovf, add_zero, add_neg;

    alu_adder #(.WIDTH(WIDTH)) u_adder (
        .i_sub      (s1_opcode == `OP_SUB),
        .i_a        (s1_a),
        .i_b        (s1_b),
        .o_result   (add_result),
        .o_carry    (add_carry),
        .o_overflow (add_ovf),
        .o_zero     (add_zero),
        .o_negative (add_neg)
    );

    // --- Multiplier ---
    wire [2*WIDTH-1:0]  mul_result;
    wire                mul_zero, mul_neg, mul_ovf;

    alu_multiplier #(.WIDTH(WIDTH)) u_mul (
        .i_a        (s1_a),
        .i_b        (s1_b),
        .o_result   (mul_result),
        .o_zero     (mul_zero),
        .o_negative (mul_neg),
        .o_overflow (mul_ovf)
    );

    // --- Divider ---
    wire [2*WIDTH-1:0]  div_result;
    wire                div_zero, div_neg, div_by_zero;

    alu_divider #(.WIDTH(WIDTH)) u_div (
        .i_a          (s1_a),
        .i_b          (s1_b),
        .o_result     (div_result),
        .o_div_by_zero(div_by_zero),
        .o_zero       (div_zero),
        .o_negative   (div_neg)
    );

    // --- Absolute value (uses adder's negate path) ---
    wire [WIDTH-1:0]    abs_result;
    wire                abs_carry, abs_ovf, abs_zero, abs_neg;

    alu_adder #(.WIDTH(WIDTH)) u_abs (
        .i_sub      (s1_a[WIDTH-1]),   // Negate only if negative
        .i_a        ({WIDTH{1'b0}}),   // 0 - A when A is negative
        .i_b        (s1_a),
        .o_result   (abs_result),
        .o_carry    (abs_carry),
        .o_overflow (abs_ovf),
        .o_zero     (abs_zero),
        .o_negative (abs_neg)
    );

    // --- Logic unit ---
    wire [WIDTH-1:0]    log_result;
    wire                log_zero, log_neg;

    alu_logic #(.WIDTH(WIDTH)) u_logic (
        .i_opcode   (s1_opcode),
        .i_a        (s1_a),
        .i_b        (s1_b),
        .o_result   (log_result),
        .o_zero     (log_zero),
        .o_negative (log_neg)
    );

    // --- Shift unit ---
    wire [WIDTH-1:0]    sh_result;
    wire                sh_zero, sh_neg;

    alu_shift #(.WIDTH(WIDTH)) u_shift (
        .i_opcode   (s1_opcode),
        .i_a        (s1_a),
        .i_b        (s1_b),
        .o_result   (sh_result),
        .o_zero     (sh_zero),
        .o_negative (sh_neg)
    );

    // --- Compare unit ---
    wire [2*WIDTH-1:0]  cmp_result;
    wire                cmp_zero;

    alu_compare #(.WIDTH(WIDTH)) u_cmp (
        .i_opcode   (s1_opcode),
        .i_a        (s1_a),
        .i_b        (s1_b),
        .o_result   (cmp_result),
        .o_zero     (cmp_zero)
    );

    // -----------------------------------------------------------------------
    // Result Mux — select based on opcode group (bits [4:3])
    // -----------------------------------------------------------------------
    reg [2*WIDTH-1:0] s2_result;
    reg [3:0]         s2_flags;
    reg               s2_valid;
    reg               s2_exception;

    always @(*) begin
        // Defaults
        s2_result    = {2*WIDTH{1'b0}};
        s2_flags     = 4'b0000;
        s2_exception = 1'b0;

        case (s1_opcode[4:3])
            // ---- Arithmetic group ----
            2'b00: begin
                case (s1_opcode)
                    `OP_ADD: begin
                        s2_result = {{WIDTH{1'b0}}, add_result};
                        s2_flags  = {add_ovf, add_carry, add_neg, add_zero};
                    end
                    `OP_SUB: begin
                        s2_result = {{WIDTH{1'b0}}, add_result};
                        s2_flags  = {add_ovf, add_carry, add_neg, add_zero};
                    end
                    `OP_MUL: begin
                        s2_result = mul_result;
                        s2_flags  = {mul_ovf, 1'b0, mul_neg, mul_zero};
                    end
                    `OP_DIV: begin
                        s2_result    = {{WIDTH{1'b0}}, div_result[WIDTH-1:0]};
                        s2_flags     = {1'b0, 1'b0, div_neg, div_zero};
                        s2_exception = div_by_zero;
                    end
                    `OP_ABS: begin
                        s2_result = {{WIDTH{1'b0}}, abs_result};
                        s2_flags  = {abs_ovf, 1'b0, 1'b0, abs_zero};
                    end
                    default: s2_result = {2*WIDTH{1'b0}};
                endcase
            end

            // ---- Logical group ----
            2'b01: begin
                s2_result = {{WIDTH{1'b0}}, log_result};
                s2_flags  = {1'b0, 1'b0, log_neg, log_zero};
            end

            // ---- Shift group ----
            2'b10: begin
                s2_result = {{WIDTH{1'b0}}, sh_result};
                s2_flags  = {1'b0, 1'b0, sh_neg, sh_zero};
            end

            // ---- Compare group ----
            2'b11: begin
                s2_result = cmp_result;
                s2_flags  = {1'b0, 1'b0, 1'b0, cmp_zero};
            end

            default: begin
                s2_result = {2*WIDTH{1'b0}};
                s2_flags  = 4'b0000;
            end
        endcase
    end

    // =========================================================================
    // STAGE 3 — Output Pipeline Registers
    // =========================================================================
    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            o_result    <= {2*WIDTH{1'b0}};
            o_flags     <= 4'b0000;
            o_valid     <= 1'b0;
            o_exception <= 1'b0;
            s2_valid    <= 1'b0;
        end else begin
            s2_valid    <= s1_valid;
            o_result    <= s2_result;
            o_flags     <= s2_flags;
            o_valid     <= s2_valid;
            o_exception <= s2_exception;
        end
    end

endmodule
