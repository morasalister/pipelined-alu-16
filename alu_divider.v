//=============================================================================
// File        : alu_divider.v
// Project     : 16-bit Pipelined ALU
// Description : 16-bit signed restoring division.
//               o_result[15:0]  = Quotient
//               o_result[31:16] = Remainder
//               o_div_by_zero   = Exception flag
//
// NOTE        : Division is the slowest unit. In a real SoC this would be
//               a multi-cycle unit with a 'valid' handshake. Here it is
//               modelled combinationally; the top-level pipeline register
//               captures the result. A TODO comment marks the handshake point.
//
// Latency     : Combinational
// Synthesis   : Fully synthesisable Verilog-2001
//=============================================================================

`include "alu_pkg.vh"

module alu_divider #(
    parameter WIDTH = `DATA_WIDTH
)(
    input  wire signed [WIDTH-1:0]   i_a,          // Dividend
    input  wire signed [WIDTH-1:0]   i_b,          // Divisor
    output reg         [2*WIDTH-1:0] o_result,      // {remainder, quotient}
    output reg                       o_div_by_zero,
    output wire                      o_zero,
    output wire                      o_negative
);

    // -----------------------------------------------------------------------
    // Work with unsigned magnitudes, restore sign at the end
    // -----------------------------------------------------------------------
    wire               a_neg     = i_a[WIDTH-1];
    wire               b_neg     = i_b[WIDTH-1];
    wire [WIDTH-1:0]   a_mag     = a_neg ? (-i_a) : i_a;
    wire [WIDTH-1:0]   b_mag     = b_neg ? (-i_b) : i_b;

    // Quotient sign: XOR of operand signs
    wire q_neg = a_neg ^ b_neg;
    // Remainder sign follows dividend sign
    wire r_neg = a_neg;

    integer         step;
    reg [WIDTH-1:0] quotient;
    reg [WIDTH:0]   partial_rem;   // 1 extra bit for trial subtraction
    reg [WIDTH-1:0] dividend_tmp;

    always @(*) begin
        o_div_by_zero = 1'b0;
        o_result      = {2*WIDTH{1'b0}};

        if (i_b == {WIDTH{1'b0}}) begin
            // ----------------------------------------------------------
            // Division by zero: set exception flag, result undefined
            // Convention: saturate quotient to MAX_INT
            // ----------------------------------------------------------
            o_div_by_zero         = 1'b1;
            o_result[WIDTH-1:0]   = {1'b0, {(WIDTH-1){1'b1}}};  // MAX positive
            o_result[2*WIDTH-1:WIDTH] = {WIDTH{1'b0}};
        end else begin
            // ----------------------------------------------------------
            // Restoring Division Algorithm
            // ----------------------------------------------------------
            quotient    = {WIDTH{1'b0}};
            partial_rem = {(WIDTH+1){1'b0}};
            dividend_tmp = a_mag;

            for (step = WIDTH-1; step >= 0; step = step - 1) begin
                // Shift partial remainder left and bring in next dividend bit
                partial_rem = {partial_rem[WIDTH-1:0], dividend_tmp[step]};

                // Trial subtraction
                partial_rem = partial_rem - {1'b0, b_mag};

                if (partial_rem[WIDTH] == 1'b1) begin
                    // Negative result: restore
                    partial_rem  = partial_rem + {1'b0, b_mag};
                    quotient[step] = 1'b0;
                end else begin
                    quotient[step] = 1'b1;
                end
            end

            // Restore signs
            o_result[WIDTH-1:0]       = q_neg ? (-quotient)             : quotient;
            o_result[2*WIDTH-1:WIDTH] = r_neg ? (-partial_rem[WIDTH-1:0]) : partial_rem[WIDTH-1:0];
        end
    end

    assign o_zero     = (o_result[WIDTH-1:0] == {WIDTH{1'b0}});
    assign o_negative = o_result[WIDTH-1];

    // TODO: For a production design, replace with a multi-cycle FSM with
    //       i_start / o_done handshake signals to meet timing closure.

endmodule
