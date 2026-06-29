//=============================================================================
// File        : alu_adder.v
// Project     : 16-bit Pipelined ALU
// Description : 16-bit Carry Lookahead Adder (CLA).
//               Supports ADD and SUB. SUB is implemented as A + (~B) + 1.
//               Flags: Zero, Negative, Carry, Overflow.
//
// Latency     : Combinational (registered at top-level pipeline stage)
// Synthesis   : Fully synthesisable Verilog-2001
//=============================================================================

`include "alu_pkg.vh"

module alu_adder #(
    parameter WIDTH = `DATA_WIDTH
)(
    input  wire                  i_sub,        // 1 = subtract, 0 = add
    input  wire [WIDTH-1:0]      i_a,
    input  wire [WIDTH-1:0]      i_b,
    output wire [WIDTH-1:0]      o_result,
    output wire                  o_carry,
    output wire                  o_overflow,
    output wire                  o_zero,
    output wire                  o_negative
);

    // -----------------------------------------------------------------------
    // 2's complement subtraction: A - B = A + (~B) + 1
    // i_sub also acts as the initial carry-in for subtraction
    // -----------------------------------------------------------------------
    wire [WIDTH-1:0] b_operand = i_b ^ {WIDTH{i_sub}};  // Conditionally invert B

    // -----------------------------------------------------------------------
    // Carry Lookahead Logic (4-bit groups, 4 groups for 16-bit)
    // Generate (G) and Propagate (P) for each bit
    // -----------------------------------------------------------------------
    wire [WIDTH-1:0] gen_g;   // Bit-level generate
    wire [WIDTH-1:0] prop_p;  // Bit-level propagate
    wire [WIDTH:0]   carry;   // carry[0] = carry-in, carry[WIDTH] = carry-out

    assign gen_g  = i_a & b_operand;
    assign prop_p = i_a ^ b_operand;
    assign carry[0] = i_sub;  // carry-in is 1 for subtraction (2's complement)

    // Group-level lookahead (unrolled for synthesis efficiency)
    genvar gi;
    generate
        for (gi = 0; gi < WIDTH; gi = gi + 1) begin : CLA_CARRY
            // c[i+1] = G[i] | (P[i] & c[i])
            assign carry[gi+1] = gen_g[gi] | (prop_p[gi] & carry[gi]);
        end
    endgenerate

    // Sum
    assign o_result   = prop_p ^ carry[WIDTH-1:0];
    assign o_carry    = carry[WIDTH];

    // Overflow: occurs when carry into MSB != carry out of MSB
    assign o_overflow = carry[WIDTH] ^ carry[WIDTH-1];

    // Zero and Negative flags
    assign o_zero     = (o_result == {WIDTH{1'b0}});
    assign o_negative = o_result[WIDTH-1];

endmodule
