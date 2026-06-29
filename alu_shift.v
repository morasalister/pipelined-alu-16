`timescale 1ns/1ps
//=============================================================================
// File        : alu_shift.v
// Project     : 16-bit Pipelined ALU
// Description : Shift and rotate operations: SLL, SRL, SRA, ROL, ROR
//               Shift amount = i_b[3:0] (max 15 for 16-bit)
//=============================================================================

`include "alu_pkg.vh"

module alu_shift #(
    parameter WIDTH = `DATA_WIDTH
)(
    input  wire [`OPCODE_WIDTH-1:0]  i_opcode,
    input  wire [WIDTH-1:0]          i_a,
    input  wire [WIDTH-1:0]          i_b,           // Shift amount in [3:0]
    output reg  [WIDTH-1:0]          o_result,
    output wire                      o_zero,
    output wire                      o_negative
);

    wire [3:0] shamt = i_b[3:0];  // Shift amount (0–15)

    always @(*) begin
        case (i_opcode)
            `OP_SLL : o_result = i_a << shamt;
            `OP_SRL : o_result = i_a >> shamt;
            // Arithmetic right shift: MSB is replicated (sign extension)
            `OP_SRA : o_result = $signed(i_a) >>> shamt;
            // Rotate Left: bits shifted out of MSB come back at LSB
            `OP_ROL : o_result = (shamt == 0) ? i_a : ((i_a << shamt) | (i_a >> (WIDTH[3:0] - shamt)));
            // Rotate Right: bits shifted out of LSB come back at MSB
            `OP_ROR : o_result = (shamt == 0) ? i_a : ((i_a >> shamt) | (i_a << (WIDTH[3:0] - shamt)));
            default : o_result = {WIDTH{1'b0}};
        endcase
    end

    assign o_zero     = (o_result == {WIDTH{1'b0}});
    assign o_negative = o_result[WIDTH-1];

endmodule
