`timescale 1ns/1ps
`include "alu.v"

module alu_64_bit_tb;
    reg [63:0] a, b;
    reg [3:0] opcode;
    wire [63:0] result;
    wire cout, carry_flag, overflow_flag, zero_flag;
    integer pass_count = 0, total_tests = 55;
    
    // Control codes
    localparam  ADD_Oper  = 4'b0000,
                SLL_Oper  = 4'b0001,
                SLT_Oper  = 4'b0010,
                SLTU_Oper = 4'b0011,
                XOR_Oper  = 4'b0100,
                SRL_Oper  = 4'b0101,
                OR_Oper   = 4'b0110,
                AND_Oper  = 4'b0111,
                SUB_Oper  = 4'b1000,
                SRA_Oper  = 4'b1101;
    
    // Instantiate the ALU
    alu_64_bit uut(
        .a(a),
        .b(b),
        .opcode(opcode),
        .result(result),
        .cout(cout),
        .carry_flag(carry_flag),
        .overflow_flag(overflow_flag),
        .zero_flag(zero_flag)
    );

    // Checks result + carry + overflow + zero (for ADD/SUB)
    task run_test;
        input [7:0] test_number;
        input [63:0] test_a, test_b, expected_result;
        input [3:0] test_opcode;
        input exp_carry, exp_overflow, exp_zero;
        begin
            a = test_a;
            b = test_b;
            opcode = test_opcode;
            #10;
            $display("Test %0d:", test_number);
            $display("  A: %016h  B: %016h  Opcode: %b", a, b, test_opcode);
            $display("  Result: %016h  Flags: C=%b, O=%b, Z=%b", result, carry_flag, overflow_flag, zero_flag);
            
            if (result === expected_result && 
                carry_flag === exp_carry && 
                overflow_flag === exp_overflow && 
                zero_flag === exp_zero) begin
                pass_count = pass_count + 1;
                $fdisplay(file_handle, "Test %0d, Status: PASS", test_number);
            end else begin
                $fdisplay(file_handle, "Test %0d, Status: FAIL", test_number);
                $display("  FAIL! Expected: result=%016h, carry=%b, overflow=%b, zero=%b", 
                        expected_result, exp_carry, exp_overflow, exp_zero);
                $display("         Got:     result=%016h, carry=%b, overflow=%b, zero=%b", 
                        result, carry_flag, overflow_flag, zero_flag);
            end
        end
    endtask

    task run_test_sub;
        input [7:0] test_number;
        input [63:0] test_a, test_b, expected_result;
        input [3:0] test_opcode;
        input exp_overflow, exp_zero;
        begin
            a = test_a;
            b = test_b;
            opcode = test_opcode;
            #10;
            $display("Test %0d:", test_number);
            $display("  A: %016h  B: %016h  Opcode: %b", a, b, test_opcode);
            $display("  Result: %016h  Flags: O=%b, Z=%b", result, overflow_flag, zero_flag);
            
            if (result === expected_result && 
                overflow_flag === exp_overflow && 
                zero_flag === exp_zero) begin
                pass_count = pass_count + 1;
                $fdisplay(file_handle, "Test %0d, Status: PASS", test_number);
            end else begin
                $fdisplay(file_handle, "Test %0d, Status: FAIL", test_number);
                $display("  FAIL! Expected: result=%016h, overflow=%b, zero=%b", 
                        expected_result, exp_overflow, exp_zero);
                $display("         Got:     result=%016h, overflow=%b, zero=%b", 
                        result, overflow_flag, zero_flag);
            end
        end
    endtask

    // Checks result + zero only (for AND, OR, XOR, shifts, comparators)
    task run_test_rz;
        input [7:0] test_number;
        input [63:0] test_a, test_b, expected_result;
        input [3:0] test_opcode;
        input exp_zero;
        begin
            a = test_a;
            b = test_b;
            opcode = test_opcode;
            #10;
            $display("Test %0d:", test_number);
            $display("  A: %016h  B: %016h  Opcode: %b", a, b, test_opcode);
            $display("  Result: %016h  Zero=%b", result, zero_flag);
            
            if (result === expected_result && zero_flag === exp_zero) begin
                pass_count = pass_count + 1;
                $fdisplay(file_handle, "Test %0d, Status: PASS", test_number);
            end else begin
                $fdisplay(file_handle, "Test %0d, Status: FAIL", test_number);
                $display("  FAIL! Expected: result=%016h, zero=%b", expected_result, exp_zero);
                $display("         Got:     result=%016h, zero=%b", result, zero_flag);
            end
        end
    endtask

    integer file_handle;

    initial begin
        file_handle = $fopen("alu_results.txt", "w");
        if (file_handle == 0) begin
            $display("Error: Could not open file for writing.");
            $finish;
        end
        $dumpfile("alu_tb.vcd");
        $dumpvars(0, alu_64_bit_tb);
        pass_count = 0;

        // ======================== ADD (opcode 0000) ========================

        // Baseline: 0 + 0 = 0, zero flag set
        run_test(1, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, ADD_Oper, 0, 0, 1);

        // Positive overflow: MAX_POS + 1 wraps to MIN_NEG
        run_test(2, 64'h7FFFFFFFFFFFFFFF, 64'h0000000000000001, 64'h8000000000000000, ADD_Oper, 0, 1, 0);

        // Simultaneous carry + overflow + zero: MIN_NEG + MIN_NEG
        run_test(3, 64'h8000000000000000, 64'h8000000000000000, 64'h0000000000000000, ADD_Oper, 1, 1, 1);

        // Unsigned wrap to zero: 0xFFF...F + 1, carry without overflow
        run_test(4, 64'hFFFFFFFFFFFFFFFF, 64'h0000000000000001, 64'h0000000000000000, ADD_Oper, 1, 0, 1);

        // Two negatives with carry, no overflow: (-1) + (-1) = -2
        run_test(5, 64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFE, ADD_Oper, 1, 0, 0);

        // Two MAX_POS overflow to negative, no carry
        run_test(6, 64'h7FFFFFFFFFFFFFFF, 64'h7FFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFE, ADD_Oper, 0, 1, 0);

        // Negative overflow with carry: MIN_NEG + (-1) = MAX_POS
        run_test(7, 64'h8000000000000000, 64'hFFFFFFFFFFFFFFFF, 64'h7FFFFFFFFFFFFFFF, ADD_Oper, 1, 1, 0);

        // Cancellation to zero with carry: 1 + (-1) = 0
        run_test(8, 64'h0000000000000001, 64'hFFFFFFFFFFFFFFFF, 64'h0000000000000000, ADD_Oper, 1, 0, 1);

        // Carry propagation across 32-bit boundary
        run_test(9, 64'h00000000FFFFFFFF, 64'h0000000000000001, 64'h0000000100000000, ADD_Oper, 0, 0, 0);

        // Random positive + positive, no overflow
        run_test(10, 64'h06EAE7CD9408D55F, 64'h0000000AA221D37B, 64'h06EAE7D8362AA8DA, ADD_Oper, 0, 0, 0);

        // Random positive + negative, no overflow
        run_test(11, 64'h0023185DDFBF101B, 64'hFFFD288475FDE3B9, 64'h002040E255BCF3D4, ADD_Oper, 1, 0, 0);

        // Mid-word carry chain: upper + lower cancel to zero
        run_test(12, 64'h0000000100000000, 64'hFFFFFFFF00000000, 64'h0000000000000000, ADD_Oper, 1, 0, 1);

        // ======================== SUB (opcode 1000) ========================

        // Baseline: 0 - 0 = 0
        run_test_sub(13, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, SUB_Oper, 0, 1);

        // Equal operands cancel: 1 - 1 = 0
        run_test_sub(14, 64'h0000000000000001, 64'h0000000000000001, 64'h0000000000000000, SUB_Oper, 0, 1);

        // Unsigned borrow: 0 - 1 wraps to all-ones
        run_test_sub(15, 64'h0000000000000000, 64'h0000000000000001, 64'hFFFFFFFFFFFFFFFF, SUB_Oper, 0, 0);

        // Signed underflow: MIN_NEG - 1 = MAX_POS, overflow
        run_test_sub(16, 64'h8000000000000000, 64'h0000000000000001, 64'h7FFFFFFFFFFFFFFF, SUB_Oper, 1, 0);

        // Signed overflow: MAX_POS - (-1) wraps to MIN_NEG
        run_test_sub(17, 64'h7FFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF, 64'h8000000000000000, SUB_Oper, 1, 0);

        // Overflow: 0 - MIN_NEG wraps back to MIN_NEG
        run_test_sub(18, 64'h0000000000000000, 64'h8000000000000000, 64'h8000000000000000, SUB_Oper, 1, 0);

        // Negative cancel: (-1) - (-1) = 0
        run_test_sub(19, 64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF, 64'h0000000000000000, SUB_Oper, 0, 1);

        // Random positive subtraction, no overflow
        run_test_sub(20, 64'h06EAE7CD9408D55F, 64'h0000000AA221D37B, 64'h06EAE7C2F1E701E4, SUB_Oper, 0, 0);

        // Random positive minus negative
        run_test_sub(21, 64'h0023185DDFBF101B, 64'hFFFD288475FDE3B9, 64'h0025EFD969C12C62, SUB_Oper, 0, 0);

        // Large minus small: all-ones - 1
        run_test_sub(22, 64'hFFFFFFFFFFFFFFFF, 64'h0000000000000001, 64'hFFFFFFFFFFFFFFFE, SUB_Oper, 0, 0);

        // Small minus large: 1 - all-ones = 2
        run_test_sub(23, 64'h0000000000000001, 64'hFFFFFFFFFFFFFFFF, 64'h0000000000000002, SUB_Oper, 0, 0);

        // ======================== AND (opcode 0111) ========================

        // Masking with zero: all-ones AND 0 = 0
        run_test_rz(24, 64'hFFFFFFFFFFFFFFFF, 64'h0000000000000000, 64'h0000000000000000, AND_Oper, 1);

        // Random AND with non-zero result
        run_test_rz(25, 64'h00002C84C4D54177, 64'h011C2D636E06D380, 64'h00002C0044044100, AND_Oper, 0);

        // Complementary patterns produce zero: 0x555... & 0xAAA... = 0
        run_test_rz(26, 64'h5555555555555555, 64'hAAAAAAAAAAAAAAAA, 64'h0000000000000000, AND_Oper, 1);

        // Upper 32-bit mask extraction
        run_test_rz(27, 64'h123456789ABCDEF0, 64'hFFFFFFFF00000000, 64'h1234567800000000, AND_Oper, 0);

        // ======================== OR (opcode 0110) ========================

        // Baseline: 0 OR 0 = 0
        run_test_rz(28, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, OR_Oper, 1);

        // Identity: all-ones OR 0 = all-ones
        run_test_rz(29, 64'hFFFFFFFFFFFFFFFF, 64'h0000000000000000, 64'hFFFFFFFFFFFFFFFF, OR_Oper, 0);

        // Complementary pattern OR
        run_test_rz(30, 64'h5555555555555555, 64'hAAAAAAAAAAAAAAAA, 64'hFFFFFFFFFFFFFFFF, OR_Oper, 0);

        // Random OR pattern
        run_test_rz(31, 64'h00002C84C4D54177, 64'h011C2D636E06D380, 64'h011C2DE7EED7D3F7, OR_Oper, 0);

        // ======================== XOR (opcode 0100) ========================

        // Baseline: 0 XOR 0 = 0
        run_test_rz(32, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, XOR_Oper, 1);

        // Complementary patterns XOR to all-ones
        run_test_rz(33, 64'h5555555555555555, 64'hAAAAAAAAAAAAAAAA, 64'hFFFFFFFFFFFFFFFF, XOR_Oper, 0);

        // Random XOR pattern
        run_test_rz(34, 64'h5555555555555555, 64'hAAAAAAAAAAAAAAAA, 64'hFFFFFFFFFFFFFFFF, XOR_Oper, 0);

        // Self-XOR cancels to zero
        run_test_rz(35, 64'h123456789ABCDEF0, 64'h123456789ABCDEF0, 64'h0000000000000000, XOR_Oper, 1);

        // ======================== SLL (opcode 0001) ========================

        // Shift by 0: no change (upper bits of b ignored)
        run_test_rz(36, 64'h0000000000000001, 64'h000BEEF000000000, 64'h0000000000000001, SLL_Oper, 0);

        // Shift 1 left by 63: LSB reaches MSB
        run_test_rz(37, 64'h0000000000000001, 64'h0000DADA0000003F, 64'h8000000000000000, SLL_Oper, 0);

        // Alternating pattern left by 1: MSB lost, LSB = 0
        run_test_rz(38, 64'hAAAAAAAAAAAAAAAA, 64'h0000000000000001, 64'h5555555555555554, SLL_Oper, 0);

        // Zero shifted stays zero
        run_test_rz(39, 64'h0000000000000000, 64'h000000000000000A, 64'h0000000000000000, SLL_Oper, 1);

        // ======================== SRL (opcode 0101) ========================

        // Shift by 0: no change (upper bits of b ignored)
        run_test_rz(40, 64'h0000000000000001, 64'h000DEAF000000000, 64'h0000000000000001, SRL_Oper, 0);

        // Right by 63: only bit 63 survives (0 here, so result = 0)
        run_test_rz(41, 64'h7000000000000000, 64'h00B00B500000003F, 64'h0000000000000000, SRL_Oper, 1);

        // MSB crosses 32-bit boundary: 0x8000...0 >> 32
        run_test_rz(42, 64'h8000000000000000, 64'h0000000000000020, 64'h0000000080000000, SRL_Oper, 0);

        // All-ones >> 32: upper half zeroed
        run_test_rz(43, 64'hFFFFFFFFFFFFFFFF, 64'h0000000000000020, 64'h00000000FFFFFFFF, SRL_Oper, 0);

        // ======================== SRA (opcode 1101) ========================

        // Sign extension: negative >> 1 fills MSB with 1
        run_test_rz(44, 64'h8000000000000000, 64'h00B00B5000000001, 64'hC000000000000000, SRA_Oper, 0);

        // Positive >> 1: same as SRL (MSB = 0 fills with 0)
        run_test_rz(45, 64'h4000000000000000, 64'h0123400000000001, 64'h2000000000000000, SRA_Oper, 0);

        // Shifted out completely: positive 1 >> 1 = 0
        run_test_rz(46, 64'h0000000000000001, 64'h00DEED0000000001, 64'h0000000000000000, SRA_Oper, 1);

        // Sign extends across 32-bit boundary: MIN_NEG >> 32
        run_test_rz(47, 64'h8000000000000000, 64'h0000000000000020, 64'hFFFFFFFF80000000, SRA_Oper, 0);

        // ======================== SLT (opcode 0010) ========================

        // Equal values: not less than
        run_test_rz(48, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, SLT_Oper, 1);

        // Negative < zero: -1 < 0
        run_test_rz(49, 64'hFFFFFFFFFFFFFFFF, 64'h0000000000000000, 64'h0000000000000001, SLT_Oper, 0);

        // Zero > negative: 0 > -1, not less than
        run_test_rz(50, 64'h0000000000000000, 64'hFFFFFFFFFFFFFFFF, 64'h0000000000000000, SLT_Oper, 1);

        // Most negative < least negative: MIN_NEG < -1
        run_test_rz(51, 64'h8000000000000000, 64'hFFFFFFFFFFFFFFFF, 64'h0000000000000001, SLT_Oper, 0);

        // ======================== SLTU (opcode 0011) ========================

        // Equal values: not less than
        run_test_rz(52, 64'h0000000000000000, 64'h0000000000000000, 64'h0000000000000000, SLTU_Oper, 1);

        // Greater operand: 1 > 0 unsigned, not less than
        run_test_rz(53, 64'h0000000000000001, 64'h0000000000000000, 64'h0000000000000000, SLTU_Oper, 1);

        // Signed/unsigned boundary: 0x7FFF...F < 0x8000...0 in unsigned
        run_test_rz(54, 64'h7FFFFFFFFFFFFFFF, 64'h8000000000000000, 64'h0000000000000001, SLTU_Oper, 0);

        // Equal MAX values: not less than
        run_test_rz(55, 64'hFFFFFFFFFFFFFFFF, 64'hFFFFFFFFFFFFFFFF, 64'h0000000000000000, SLTU_Oper, 1);

        // ======================== FINAL SUMMARY ========================
        $display("\n========================================");
        $display("  FINAL RESULT: Passed %0d/%0d tests", pass_count, total_tests);
        $display("========================================\n");
        $fdisplay(file_handle, "Passed %0d/%0d tests", pass_count, total_tests);
        $fclose(file_handle);
        #10 $finish;
    end
endmodule