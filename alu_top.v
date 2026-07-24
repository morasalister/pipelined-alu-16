`timescale 1ns/1ps
//=============================================================================
// File        : alu_top.v
// Project     : 16-bit Pipelined ALU
//
// Description : 3-stage pipelined ALU. Compare operations no longer use a
//               dedicated alu_compare module. Instead they reuse the adder's
//               subtraction path (A - B) and decode the resulting flags to
//               produce a boolean result, exactly as ARM/x86 CMP works.
//
//   Stage 1: Input registers (i_a, i_b, i_opcode, i_cin, i_valid)
//   Stage 2: Execute        (all submodules combinational, result mux)
//   Stage 3: Output registers (o_result, o_flags, o_cmp_true, o_valid)
//
// New output:
//   o_cmp_true : 1 when compare condition is satisfied, 0 otherwise.
//                Only meaningful when the opcode is a compare (bits[4:3]=2'b11)
//   o_result   : 32'h0 for compare ops (result is intentionally discarded,
//                as in a real CMP instruction)
//=============================================================================

`include "alu_pkg.vh"

module alu_top #(
    parameter WIDTH = `DATA_WIDTH
)(
    input  wire                       i_clk,
    input  wire                       i_rst_n,

    input  wire                       i_valid,
    input  wire                       i_cin,
    input  wire [`OPCODE_WIDTH-1:0]  i_opcode,
    input  wire [WIDTH-1:0]           i_a,
    input  wire [WIDTH-1:0]           i_b,

    output reg  [2*WIDTH-1:0]         o_result,
    output reg  [3:0]                 o_flags,
    output reg                        o_cmp_true,   // NEW: boolean compare result
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
    reg                       s1_cin;

    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            s1_valid  <= 1'b0;
            s1_opcode <= {`OPCODE_WIDTH{1'b0}};
            s1_a      <= {WIDTH{1'b0}};
            s1_b      <= {WIDTH{1'b0}};
            s1_cin    <= 1'b0;
        end else begin
            s1_valid  <= i_valid;
            s1_opcode <= i_opcode;
            s1_a      <= i_a;
            s1_b      <= i_b;
            s1_cin    <= i_cin;
        end
    end

    // =========================================================================
    // STAGE 2 — Execute
    // =========================================================================

    // -------------------------------------------------------------------------
    // Adder — handles ADD, SUB, ADC, SBC, ABS, and now also CMP
    // -------------------------------------------------------------------------
    wire [WIDTH-1:0]  add_result;
    wire              add_carry, add_ovf, add_zero, add_neg;

    // For compare ops (opcode[4:3] == 2'b11), always subtract (A - B)
    wire is_cmp = (s1_opcode[4:3] == 2'b11);
    wire do_sub = (s1_opcode == `OP_SUB) | (s1_opcode == `OP_SBC) | is_cmp;

    alu_adder #(.WIDTH(WIDTH)) u_adder (
        .i_sub      (do_sub),
        .i_cin      (s1_cin & ~is_cmp),  // carry-in only for ADC/SBC, not CMP
        .i_a        (s1_a),
        .i_b        (s1_b),
        .o_result   (add_result),
        .o_carry    (add_carry),
        .o_overflow (add_ovf),
        .o_zero     (add_zero),
        .o_negative (add_neg)
    );

    // -------------------------------------------------------------------------
    // ABS — separate adder instance (0 - A when A is negative)
    // -------------------------------------------------------------------------
    wire [WIDTH-1:0]  abs_result;
    wire              abs_carry, abs_ovf, abs_zero, abs_neg;

    alu_adder #(.WIDTH(WIDTH)) u_abs (
        .i_sub      (s1_a[WIDTH-1]),
        .i_cin      (1'b0),
        .i_a        ({WIDTH{1'b0}}),
        .i_b        (s1_a),
        .o_result   (abs_result),
        .o_carry    (abs_carry),
        .o_overflow (abs_ovf),
        .o_zero     (abs_zero),
        .o_negative (abs_neg)
    );

    // -------------------------------------------------------------------------
    // Multiplier
    // -------------------------------------------------------------------------
    wire [2*WIDTH-1:0] mul_result;
    wire               mul_zero, mul_neg, mul_ovf;

    alu_multiplier #(.WIDTH(WIDTH)) u_mul (
        .i_a        (s1_a),
        .i_b        (s1_b),
        .o_result   (mul_result),
        .o_zero     (mul_zero),
        .o_negative (mul_neg),
        .o_overflow (mul_ovf)
    );

    // -------------------------------------------------------------------------
    // Divider
    // -------------------------------------------------------------------------
    wire [2*WIDTH-1:0] div_result;
    wire               div_zero, div_neg, div_by_zero;

    alu_divider #(.WIDTH(WIDTH)) u_div (
        .i_a          (s1_a),
        .i_b          (s1_b),
        .o_result     (div_result),
        .o_div_by_zero(div_by_zero),
        .o_zero       (div_zero),
        .o_negative   (div_neg)
    );

    // -------------------------------------------------------------------------
    // Logic unit
    // -------------------------------------------------------------------------
    wire [WIDTH-1:0]  log_result;
    wire              log_zero, log_neg;

    alu_logic #(.WIDTH(WIDTH)) u_logic (
        .i_opcode   (s1_opcode),
        .i_a        (s1_a),
        .i_b        (s1_b),
        .o_result   (log_result),
        .o_zero     (log_zero),
        .o_negative (log_neg)
    );

    // -------------------------------------------------------------------------
    // Shift unit
    // -------------------------------------------------------------------------
    wire [WIDTH-1:0]  sh_result;
    wire              sh_zero, sh_neg;

    alu_shift #(.WIDTH(WIDTH)) u_shift (
        .i_opcode   (s1_opcode),
        .i_a        (s1_a),
        .i_b        (s1_b),
        .o_result   (sh_result),
        .o_zero     (sh_zero),
        .o_negative (sh_neg)
    );

    // -------------------------------------------------------------------------
    // Compare flag decoder
    // Computes A - B via the shared adder above, then decodes flags.
    //
    // Flag conditions (derived from A - B):
    //   EQ  : Zero
    //   NEQ : ~Zero
    //   LT  : Negative ^ Overflow          (signed less-than)
    //   GT  : ~Zero & ~(Negative ^ Overflow)(signed greater-than)
    //   LTE :  Zero | (Negative ^ Overflow) (signed less-or-equal)
    //   GTE : ~(Negative ^ Overflow)        (signed greater-or-equal)
    //   ULT :  Carry                        (unsigned less-than = borrow)
    //   UGT : ~Carry & ~Zero               (unsigned greater-than)
    // -------------------------------------------------------------------------
    wire n_xor_v = add_neg ^ add_ovf;   // shared term used by signed comparisons

    reg cmp_true;
    always @(*) begin
        case (s1_opcode)
            `OP_EQ  : cmp_true = add_zero;
            `OP_NEQ : cmp_true = ~add_zero;
            `OP_LT  : cmp_true =  n_xor_v;
            `OP_GT  : cmp_true = ~add_zero & ~n_xor_v;
            `OP_LTE : cmp_true =  add_zero |  n_xor_v;
            `OP_GTE : cmp_true = ~n_xor_v;
            `OP_ULT : cmp_true =  add_carry;
            `OP_UGT : cmp_true = ~add_carry & ~add_zero;
            default : cmp_true = 1'b0;
        endcase
    end

    // -------------------------------------------------------------------------
    // Result Mux
    // -------------------------------------------------------------------------
    reg [2*WIDTH-1:0] s2_result;
    reg [3:0]         s2_flags;
    reg               s2_valid;
    reg               s2_exception;
    reg               s2_cmp_true;

    always @(*) begin
        s2_result    = {2*WIDTH{1'b0}};
        s2_flags     = 4'b0000;
        s2_exception = 1'b0;
        s2_cmp_true  = 1'b0;

        case (s1_opcode[4:3])

            // ---- Arithmetic ----
            2'b00: begin
                case (s1_opcode)
                    `OP_ADD,
                    `OP_ADC: begin
                        s2_result = {{WIDTH{1'b0}}, add_result};
                        s2_flags  = {add_ovf, add_carry, add_neg, add_zero};
                    end
                    `OP_SUB,
                    `OP_SBC: begin
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

            // ---- Logical ----
            2'b01: begin
                s2_result = {{WIDTH{1'b0}}, log_result};
                s2_flags  = {1'b0, 1'b0, log_neg, log_zero};
            end

            // ---- Shift ----
            2'b10: begin
                s2_result = {{WIDTH{1'b0}}, sh_result};
                s2_flags  = {1'b0, 1'b0, sh_neg, sh_zero};
            end

            // ---- Compare ----
            // Result bus is intentionally zeroed — like a real CMP instruction.
            // The caller reads o_cmp_true and o_flags instead.
            // Flags are set from A - B so the caller can chain conditions.
            2'b11: begin
                s2_result   = {2*WIDTH{1'b0}};
                s2_flags    = {add_ovf, add_carry, add_neg, add_zero};
                s2_cmp_true = cmp_true;
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
            o_cmp_true  <= 1'b0;
            o_valid     <= 1'b0;
            o_exception <= 1'b0;
            s2_valid    <= 1'b0;
        end else begin
            s2_valid    <= s1_valid;
            o_result    <= s2_result;
            o_flags     <= s2_flags;
            o_cmp_true  <= s2_cmp_true;
            o_valid     <= s2_valid;
            o_exception <= s2_exception;
        end
    end

endmodule
