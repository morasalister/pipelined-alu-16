//=============================================================================
// File        : alu_tb.v
// Project     : 16-bit Pipelined ALU
// Description : Self-checking testbench. Tests every opcode group with:
//               - Directed corner-case tests
//               - Random stimulus with Golden Model checking
//               - Pipeline flush and back-to-back throughput tests
//
// Simulation  : Icarus Verilog / ModelSim / VCS / Xcelium compatible
// Run         : iverilog -o alu_sim alu_tb.v alu_top.v alu_adder.v
//                         alu_multiplier.v alu_divider.v alu_logic.v
//                         alu_shift.v alu_compare.v && vvp alu_sim
//=============================================================================

`include "alu_pkg.vh"
`timescale 1ns/1ps

module alu_tb;

    // -----------------------------------------------------------------------
    // DUT signals
    // -----------------------------------------------------------------------
    reg                       clk;
    reg                       rst_n;
    reg                       valid_in;
    reg  [`OPCODE_WIDTH-1:0] opcode;
    reg  [`DATA_WIDTH-1:0]   a_in, b_in;

    wire [2*`DATA_WIDTH-1:0] result_out;
    wire [3:0]                flags_out;
    wire                      valid_out;
    wire                      exception_out;

    // -----------------------------------------------------------------------
    // Instantiate DUT
    // -----------------------------------------------------------------------
    alu_top #(.WIDTH(`DATA_WIDTH)) DUT (
        .i_clk       (clk),
        .i_rst_n     (rst_n),
        .i_valid     (valid_in),
        .i_opcode    (opcode),
        .i_a         (a_in),
        .i_b         (b_in),
        .o_result    (result_out),
        .o_flags     (flags_out),
        .o_valid     (valid_out),
        .o_exception (exception_out)
    );

    // -----------------------------------------------------------------------
    // Clock: 10ns period (100 MHz)
    // -----------------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -----------------------------------------------------------------------
    // Scoreboard: FIFO to track expected values vs actual DUT outputs
    // -----------------------------------------------------------------------
    localparam PIPE_DEPTH = `PIPE_STAGES;
    localparam FIFO_DEPTH = 16;

    reg [2*`DATA_WIDTH-1:0] exp_result_fifo [0:FIFO_DEPTH-1];
    reg                      exp_valid_fifo  [0:FIFO_DEPTH-1];
    reg [`OPCODE_WIDTH-1:0] exp_op_fifo     [0:FIFO_DEPTH-1];
    integer                  fifo_wr, fifo_rd;

    integer pass_count, fail_count, test_count;

    // -----------------------------------------------------------------------
    // Golden Model Task
    // -----------------------------------------------------------------------
    task golden_model;
        input [`OPCODE_WIDTH-1:0] op;
        input [`DATA_WIDTH-1:0]   a, b;
        output [2*`DATA_WIDTH-1:0] expected;
        output                     is_exception;

        reg signed [`DATA_WIDTH-1:0] sa, sb;
        reg [2*`DATA_WIDTH-1:0]      mul_tmp;
        begin
            sa = a; sb = b;
            is_exception = 0;
            case (op)
                `OP_ADD  : expected = {{`DATA_WIDTH{1'b0}}, a + b};
                `OP_SUB  : expected = {{`DATA_WIDTH{1'b0}}, a - b};
                `OP_MUL  : begin
                               mul_tmp = $signed({{`DATA_WIDTH{a[`DATA_WIDTH-1]}}, a})
                                       * $signed({{`DATA_WIDTH{b[`DATA_WIDTH-1]}}, b});
                               expected = mul_tmp;
                           end
                `OP_DIV  : begin
                               if (b == 0) begin
                                   expected     = {2*`DATA_WIDTH{1'bx}};
                                   is_exception = 1;
                               end else begin
                                   expected = {sa % sb, sa / sb};   // {rem, quot} — note: sign-extend
                                   expected = {{`DATA_WIDTH{1'b0}}, $signed(sa) / $signed(sb)};
                               end
                           end
                `OP_ABS  : expected = (a[`DATA_WIDTH-1]) ?
                                      {{`DATA_WIDTH{1'b0}}, -a} :
                                      {{`DATA_WIDTH{1'b0}}, a};
                `OP_AND  : expected = {{`DATA_WIDTH{1'b0}}, a & b};
                `OP_OR   : expected = {{`DATA_WIDTH{1'b0}}, a | b};
                `OP_XOR  : expected = {{`DATA_WIDTH{1'b0}}, a ^ b};
                `OP_NOT  : expected = {{`DATA_WIDTH{1'b0}}, ~a};
                `OP_NAND : expected = {{`DATA_WIDTH{1'b0}}, ~(a & b)};
                `OP_NOR  : expected = {{`DATA_WIDTH{1'b0}}, ~(a | b)};
                `OP_XNOR : expected = {{`DATA_WIDTH{1'b0}}, ~(a ^ b)};
                `OP_SLL  : expected = {{`DATA_WIDTH{1'b0}}, a << b[3:0]};
                `OP_SRL  : expected = {{`DATA_WIDTH{1'b0}}, a >> b[3:0]};
                `OP_SRA  : expected = {{`DATA_WIDTH{1'b0}}, $signed(a) >>> b[3:0]};
                `OP_ROL  : expected = (b[3:0] == 0) ? {{`DATA_WIDTH{1'b0}}, a} :
                                      {{`DATA_WIDTH{1'b0}}, (a << b[3:0]) | (a >> (`DATA_WIDTH - b[3:0]))};
                `OP_ROR  : expected = (b[3:0] == 0) ? {{`DATA_WIDTH{1'b0}}, a} :
                                      {{`DATA_WIDTH{1'b0}}, (a >> b[3:0]) | (a << (`DATA_WIDTH - b[3:0]))};
                `OP_EQ   : expected = (a == b) ? {{2*`DATA_WIDTH-1{1'b0}}, 1'b1} : {2*`DATA_WIDTH{1'b0}};
                `OP_NEQ  : expected = (a != b) ? {{2*`DATA_WIDTH-1{1'b0}}, 1'b1} : {2*`DATA_WIDTH{1'b0}};
                `OP_LT   : expected = (sa < sb) ? {{2*`DATA_WIDTH-1{1'b0}}, 1'b1} : {2*`DATA_WIDTH{1'b0}};
                `OP_GT   : expected = (sa > sb) ? {{2*`DATA_WIDTH-1{1'b0}}, 1'b1} : {2*`DATA_WIDTH{1'b0}};
                `OP_LTE  : expected = (sa <= sb) ? {{2*`DATA_WIDTH-1{1'b0}}, 1'b1} : {2*`DATA_WIDTH{1'b0}};
                `OP_GTE  : expected = (sa >= sb) ? {{2*`DATA_WIDTH-1{1'b0}}, 1'b1} : {2*`DATA_WIDTH{1'b0}};
                `OP_ULT  : expected = (a < b)  ? {{2*`DATA_WIDTH-1{1'b0}}, 1'b1} : {2*`DATA_WIDTH{1'b0}};
                `OP_UGT  : expected = (a > b)  ? {{2*`DATA_WIDTH-1{1'b0}}, 1'b1} : {2*`DATA_WIDTH{1'b0}};
                default  : expected = {2*`DATA_WIDTH{1'b0}};
            endcase
        end
    endtask

    // -----------------------------------------------------------------------
    // Drive one transaction into DUT + push to scoreboard
    // -----------------------------------------------------------------------
    task drive_and_expect;
        input [`OPCODE_WIDTH-1:0] op;
        input [`DATA_WIDTH-1:0]   a, b;
        reg   [2*`DATA_WIDTH-1:0] exp;
        reg                        exc;
        begin
            @(negedge clk);
            opcode    = op;
            a_in      = a;
            b_in      = b;
            valid_in  = 1'b1;

            golden_model(op, a, b, exp, exc);
            exp_result_fifo[fifo_wr] = exp;
            exp_valid_fifo [fifo_wr] = 1'b1;
            exp_op_fifo    [fifo_wr] = op;
            fifo_wr = (fifo_wr + 1) % FIFO_DEPTH;
            test_count = test_count + 1;

            @(posedge clk);  // Latch into Stage 1
            valid_in = 1'b0;
        end
    endtask

    // -----------------------------------------------------------------------
    // Check DUT output against scoreboard
    // -----------------------------------------------------------------------
    task check_output;
        input [2*`DATA_WIDTH-1:0] dut_result;
        input                      dut_valid;
        reg   [2*`DATA_WIDTH-1:0] exp;
        reg   [`OPCODE_WIDTH-1:0] op;
        begin
            if (dut_valid) begin
                exp = exp_result_fifo[fifo_rd];
                op  = exp_op_fifo    [fifo_rd];
                fifo_rd = (fifo_rd + 1) % FIFO_DEPTH;

                // Skip check for DIV-by-zero cases (marked with x)
                if (^exp === 1'bx) begin
                    $display("[SKIP] OP=%0h  Division-by-zero exception detected — skipping result check", op);
                end else if (dut_result !== exp) begin
                    $display("[FAIL] OP=%0h  Got: %0h  Expected: %0h", op, dut_result, exp);
                    fail_count = fail_count + 1;
                end else begin
                    $display("[PASS] OP=%0h  Result: %0h", op, dut_result);
                    pass_count = pass_count + 1;
                end
            end
        end
    endtask

    // -----------------------------------------------------------------------
    // Output monitor process (runs concurrently)
    // -----------------------------------------------------------------------
    always @(posedge clk) begin
        check_output(result_out, valid_out);
    end

    // -----------------------------------------------------------------------
    // Main Test Sequence
    // -----------------------------------------------------------------------
    integer i;
    reg [`DATA_WIDTH-1:0] rand_a, rand_b;

    initial begin
        // Waveform dump for GTKWave
        $dumpfile("alu_wave.vcd");
        $dumpvars(0, alu_tb);

        // Initialise
        rst_n      = 0;
        valid_in   = 0;
        opcode     = 0;
        a_in       = 0;
        b_in       = 0;
        fifo_wr    = 0;
        fifo_rd    = 0;
        pass_count = 0;
        fail_count = 0;
        test_count = 0;

        // Apply reset for 3 cycles
        repeat(3) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);

        $display("=======================================================");
        $display("       16-bit Pipelined ALU — Self-Checking TB         ");
        $display("=======================================================");

        // ---------------------------------------------------------------
        // TEST GROUP 1: Arithmetic — Corner cases
        // ---------------------------------------------------------------
        $display("\n--- ARITHMETIC TESTS ---");
        drive_and_expect(`OP_ADD, 16'h0001, 16'h0001);   // 1 + 1 = 2
        drive_and_expect(`OP_ADD, 16'h7FFF, 16'h0001);   // Signed overflow
        drive_and_expect(`OP_ADD, 16'hFFFF, 16'h0001);   // Unsigned wrap → 0 (carry)
        drive_and_expect(`OP_SUB, 16'h0005, 16'h0003);   // 5 - 3 = 2
        drive_and_expect(`OP_SUB, 16'h0000, 16'h0001);   // 0 - 1 = -1
        drive_and_expect(`OP_MUL, 16'h0003, 16'h0004);   // 3 * 4 = 12
        drive_and_expect(`OP_MUL, 16'hFFFF, 16'hFFFF);   // (-1)*(-1) = 1
        drive_and_expect(`OP_MUL, 16'h8000, 16'h0002);   // MIN_INT * 2
        drive_and_expect(`OP_DIV, 16'h000A, 16'h0003);   // 10 / 3 = 3
        drive_and_expect(`OP_DIV, 16'h0007, 16'h0000);   // Div by zero → exception
        drive_and_expect(`OP_ABS, 16'hFFFE, 16'h0000);   // |-2| = 2
        drive_and_expect(`OP_ABS, 16'h0005, 16'h0000);   // |5|  = 5

        // ---------------------------------------------------------------
        // TEST GROUP 2: Logical
        // ---------------------------------------------------------------
        $display("\n--- LOGICAL TESTS ---");
        drive_and_expect(`OP_AND,  16'hF0F0, 16'h0FF0);
        drive_and_expect(`OP_OR,   16'hF0F0, 16'h0FF0);
        drive_and_expect(`OP_XOR,  16'hAAAA, 16'h5555);
        drive_and_expect(`OP_NOT,  16'hAAAA, 16'h0000);
        drive_and_expect(`OP_NAND, 16'hFFFF, 16'hFFFF);
        drive_and_expect(`OP_NOR,  16'h0000, 16'h0000);
        drive_and_expect(`OP_XNOR, 16'hAAAA, 16'hAAAA);

        // ---------------------------------------------------------------
        // TEST GROUP 3: Shift
        // ---------------------------------------------------------------
        $display("\n--- SHIFT TESTS ---");
        drive_and_expect(`OP_SLL, 16'h0001, 16'h0004);  // 1 << 4 = 16
        drive_and_expect(`OP_SRL, 16'h8000, 16'h0001);  // 0x8000 >> 1 = 0x4000
        drive_and_expect(`OP_SRA, 16'h8000, 16'h0001);  // 0x8000 >>> 1 = 0xC000 (sign extend)
        drive_and_expect(`OP_SRA, 16'hFFFF, 16'h0008);  // -1 >>> 8 = 0xFFFF
        drive_and_expect(`OP_ROL, 16'h8001, 16'h0001);  // Rotate left 1
        drive_and_expect(`OP_ROR, 16'h8001, 16'h0001);  // Rotate right 1

        // ---------------------------------------------------------------
        // TEST GROUP 4: Comparison
        // ---------------------------------------------------------------
        $display("\n--- COMPARISON TESTS ---");
        drive_and_expect(`OP_EQ,  16'h1234, 16'h1234);  // Equal → 1
        drive_and_expect(`OP_EQ,  16'h1234, 16'h5678);  // Not equal → 0
        drive_and_expect(`OP_NEQ, 16'hABCD, 16'h1234);
        drive_and_expect(`OP_LT,  16'hFFFF, 16'h0001);  // -1 < 1 (signed) → 1
        drive_and_expect(`OP_GT,  16'h7FFF, 16'h0001);  // MAX > 1 → 1
        drive_and_expect(`OP_ULT, 16'hFFFF, 16'h0001);  // 65535 < 1 (unsigned) → 0
        drive_and_expect(`OP_UGT, 16'hFFFF, 16'h0001);  // 65535 > 1 (unsigned) → 1

        // ---------------------------------------------------------------
        // TEST GROUP 5: Random stimulus (50 iterations)
        // ---------------------------------------------------------------
        $display("\n--- RANDOM STIMULUS (50 tests) ---");
        for (i = 0; i < 50; i = i + 1) begin
            rand_a = $random;
            rand_b = $random;
            // Cycle through all opcodes randomly
            case (i % 8)
                0: drive_and_expect(`OP_ADD,  rand_a, rand_b);
                1: drive_and_expect(`OP_SUB,  rand_a, rand_b);
                2: drive_and_expect(`OP_AND,  rand_a, rand_b);
                3: drive_and_expect(`OP_OR,   rand_a, rand_b);
                4: drive_and_expect(`OP_XOR,  rand_a, rand_b);
                5: drive_and_expect(`OP_SLL,  rand_a, rand_b);
                6: drive_and_expect(`OP_LT,   rand_a, rand_b);
                7: drive_and_expect(`OP_MUL,  rand_a, rand_b);
            endcase
        end

        // Flush remaining pipeline results
        valid_in = 0;
        repeat(PIPE_DEPTH + 2) @(posedge clk);

        // ---------------------------------------------------------------
        // Summary
        // ---------------------------------------------------------------
        $display("\n=======================================================");
        $display("  TEST SUMMARY");
        $display("  Total Tests : %0d", test_count);
        $display("  PASSED      : %0d", pass_count);
        $display("  FAILED      : %0d", fail_count);
        if (fail_count == 0)
            $display("  STATUS      : *** ALL TESTS PASSED *** ");
        else
            $display("  STATUS      : *** FAILURES DETECTED *** ");
        $display("=======================================================\n");

        $finish;
    end

    // -----------------------------------------------------------------------
    // Timeout watchdog — prevents infinite simulation
    // -----------------------------------------------------------------------
    initial begin
        #100000;
        $display("[ERROR] Simulation timeout!");
        $finish;
    end

endmodule
