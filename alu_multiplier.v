`timescale 1ns/1ps
`include "alu_pkg.vh"

module alu_multiplier #(
    parameter WIDTH = `DATA_WIDTH
)(
    input  wire signed [WIDTH-1:0]    i_a,
    input  wire signed [WIDTH-1:0]    i_b,
    output wire        [2*WIDTH-1:0]  o_result,
    output wire                       o_zero,
    output wire                       o_negative,
    output wire                       o_overflow
);

    wire signed [2*WIDTH-1:0] a_ext = {{WIDTH{i_a[WIDTH-1]}}, i_a};

    reg signed [2*WIDTH-1:0] accumulator;
    reg signed [2*WIDTH-1:0] shifted_a;
    reg signed [2*WIDTH-1:0] shifted_na;
    reg        [WIDTH:0]     b_ext;

    integer i;
    reg cur_bit, prev_bit;

    always @(*) begin
        b_ext       = {i_b, 1'b0};
        accumulator = {2*WIDTH{1'b0}};

        for (i = 0; i < WIDTH; i = i + 1) begin
            cur_bit  = b_ext[i+1];
            prev_bit = b_ext[i];

            shifted_a  =  a_ext <<< i;
            shifted_na = (-a_ext) <<< i;

            if (cur_bit == 1'b0 && prev_bit == 1'b1)
                accumulator = accumulator + shifted_a;
            else if (cur_bit == 1'b1 && prev_bit == 1'b0)
                accumulator = accumulator + shifted_na;
        end
    end

    assign o_result   = accumulator;
    assign o_zero     = (accumulator == {2*WIDTH{1'b0}});
    assign o_negative = accumulator[2*WIDTH-1];
    assign o_overflow = (accumulator[2*WIDTH-1:WIDTH] != {WIDTH{accumulator[WIDTH-1]}});

endmodule
