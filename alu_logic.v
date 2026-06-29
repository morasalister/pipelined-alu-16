//=============================================================================
// File        : alu_logic.v
// Project     : 16-bit Pipelined ALU
// Description : Bitwise logical operations: AND, OR, XOR, NOT, NAND, NOR, XNOR
//=============================================================================

`include "alu_pkg.vh"

module alu_logic #(
    parameter WIDTH = `DATA_WIDTH
)(
    input  wire [`OPCODE_WIDTH-1:0] i_opcode,
    input  wire [WIDTH-1:0]         i_a,
    input  wire [WIDTH-1:0]         i_b,
    output reg  [WIDTH-1:0]         o_result,
    output wire                     o_zero,
    output wire                     o_negative
);

    always @(*) begin
        case (i_opcode)
            `OP_AND  : o_result = i_a & i_b;
            `OP_OR   : o_result = i_a | i_b;
            `OP_XOR  : o_result = i_a ^ i_b;
            `OP_NOT  : o_result = ~i_a;
            `OP_NAND : o_result = ~(i_a & i_b);
            `OP_NOR  : o_result = ~(i_a | i_b);
            `OP_XNOR : o_result = ~(i_a ^ i_b);
            default  : o_result = {WIDTH{1'b0}};
        endcase
    end

    assign o_zero     = (o_result == {WIDTH{1'b0}});
    assign o_negative = o_result[WIDTH-1];

endmodule
