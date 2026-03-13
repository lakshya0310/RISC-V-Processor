`timescale 1ns/1ps

module immgen_tb;

reg  [31:0] instruction;
wire [63:0] imm_out;

immgen uut (
    .instruction(instruction),
    .imm_out(imm_out)
);

initial begin
    // ---- Waveform dump ----
    $dumpfile("immgen.vcd");
    $dumpvars(0, immgen_tb);

    $display("Time\tInstruction\tImm_out");
    $display("---------------------------------------");

    // =====================
    // TEST 1 : I-type (ADDI)
    // addi x2, x0, 5
    // immediate = 5
    // =====================
    instruction = 32'h00500113;
    #10;
    $display("%t\t%h\t%h", $time, instruction, imm_out);

    // =====================
    // TEST 2 : I-type (negative immediate)
    // addi x2, x0, -1
    // =====================
    instruction = 32'hFFF00113;
    #10;
    $display("%t\t%h\t%h", $time, instruction, imm_out);

    // =====================
    // TEST 3 : S-type (STORE)
    // sw x1, 8(x2)
    // immediate = 8
    // =====================
    instruction = 32'h00112423;
    #10;
    $display("%t\t%h\t%h", $time, instruction, imm_out);

    // =====================
    // TEST 4 : B-type (BEQ)
    // branch offset example
    // =====================
    instruction = 32'h00208663;
    #10;
    $display("%t\t%h\t%h", $time, instruction, imm_out);

    #10;
    $finish;
end

endmodule