//=============================================================================
// File        : alu_compare.v
// Project     : 16-bit Pipelined ALU
// Description : Comparison operations. Result is 32'b1 (true) or 32'b0 (false).
//               Supports both signed and unsigned comparisons.
//=============================================================================

`include "alu_pkg.vh"

module alu_compare #(
    parameter WIDTH = `DATA_WIDTH
)(
    input  wire [`OPCODE_WIDTH-1:0]  i_opcode,
    input  wire [WIDTH-1:0]          i_a,
    input  wire [WIDTH-1:0]          i_b,
    output reg  [2*WIDTH-1:0]        o_result,   // 32-bit: 1 = true, 0 = false
    output wire                      o_zero       // True when comparison is false (result=0)
);

    wire signed [WIDTH-1:0] a_s = i_a;
    wire signed [WIDTH-1:0] b_s = i_b;

    always @(*) begin
        case (i_opcode)
            `OP_EQ  : o_result = (i_a == i_b)  ? {{2*WIDTH-1{1'b0}}, 1'b1} : {2*WIDTH{1'b0}};
            `OP_NEQ : o_result = (i_a != i_b)  ? {{2*WIDTH-1{1'b0}}, 1'b1} : {2*WIDTH{1'b0}};
            `OP_LT  : o_result = (a_s <  b_s)  ? {{2*WIDTH-1{1'b0}}, 1'b1} : {2*WIDTH{1'b0}};
            `OP_GT  : o_result = (a_s >  b_s)  ? {{2*WIDTH-1{1'b0}}, 1'b1} : {2*WIDTH{1'b0}};
            `OP_LTE : o_result = (a_s <= b_s)  ? {{2*WIDTH-1{1'b0}}, 1'b1} : {2*WIDTH{1'b0}};
            `OP_GTE : o_result = (a_s >= b_s)  ? {{2*WIDTH-1{1'b0}}, 1'b1} : {2*WIDTH{1'b0}};
            `OP_ULT : o_result = (i_a <  i_b)  ? {{2*WIDTH-1{1'b0}}, 1'b1} : {2*WIDTH{1'b0}};
            `OP_UGT : o_result = (i_a >  i_b)  ? {{2*WIDTH-1{1'b0}}, 1'b1} : {2*WIDTH{1'b0}};
            default : o_result = {2*WIDTH{1'b0}};
        endcase
    end

    assign o_zero = (o_result == {2*WIDTH{1'b0}});

endmodule
