`timescale 1ns/1ps
`include "execute_stage.v"
module execute_stage_tb;

////////////////////////////////////////////////////////////
// Inputs
////////////////////////////////////////////////////////////

reg [31:0] instruction;
reg [63:0] read_data1;
reg [63:0] read_data2;
reg [63:0] immediate;

////////////////////////////////////////////////////////////
// Outputs
////////////////////////////////////////////////////////////

wire [63:0] alu_result;
wire zero_flag;
wire branch_taken;

wire MemRead;
wire MemWrite;
wire MemtoReg;
wire RegWrite;

////////////////////////////////////////////////////////////
// Instantiate execute_stage
////////////////////////////////////////////////////////////

execute_stage uut (

    .instruction(instruction),
    .read_data1(read_data1),
    .read_data2(read_data2),
    .immediate(immediate),

    .alu_result(alu_result),
    .zero_flag(zero_flag),
    .branch_taken(branch_taken),

    .MemRead(MemRead),
    .MemWrite(MemWrite),
    .MemtoReg(MemtoReg),
    .RegWrite(RegWrite)

);

////////////////////////////////////////////////////////////
// Test sequence
////////////////////////////////////////////////////////////

initial begin

    $display("Starting Execute Stage Testbench...");
    $display("------------------------------------------------");

////////////////////////////////////////////////////////////
// TEST 1: ADD
////////////////////////////////////////////////////////////

    instruction = 32'b0000000_00010_00001_000_00011_0110011;
    read_data1 = 10;
    read_data2 = 5;
    immediate = 0;

    #10;

    $display("ADD Result = %d (Expected 15)", alu_result);

////////////////////////////////////////////////////////////
// TEST 2: SUB
////////////////////////////////////////////////////////////

    instruction = 32'b0100000_00010_00001_000_00011_0110011;
    read_data1 = 10;
    read_data2 = 5;

    #10;

    $display("SUB Result = %d (Expected 5)", alu_result);

////////////////////////////////////////////////////////////
// TEST 3: ADDI
////////////////////////////////////////////////////////////

    instruction = 32'b000000000101_00001_000_00011_0010011;
    read_data1 = 10;
    immediate = 20;

    #10;

    $display("ADDI Result = %d (Expected 30)", alu_result);

////////////////////////////////////////////////////////////
// TEST 4: AND
////////////////////////////////////////////////////////////

    instruction = 32'b0000000_00010_00001_111_00011_0110011;
    read_data1 = 10;
    read_data2 = 6;

    #10;

    $display("AND Result = %d (Expected 2)", alu_result);

////////////////////////////////////////////////////////////
// TEST 5: OR
////////////////////////////////////////////////////////////

    instruction = 32'b0000000_00010_00001_110_00011_0110011;
    read_data1 = 10;
    read_data2 = 6;

    #10;

    $display("OR Result = %d (Expected 14)", alu_result);

////////////////////////////////////////////////////////////
// TEST 6: BEQ (equal)
////////////////////////////////////////////////////////////

    instruction = 32'b0000000_00010_00001_000_00000_1100011;
    read_data1 = 10;
    read_data2 = 10;

    #10;

    $display("BEQ Equal: branch_taken = %b (Expected 1)", branch_taken);

////////////////////////////////////////////////////////////
// TEST 7: BEQ (not equal)
////////////////////////////////////////////////////////////

    instruction = 32'b0000000_00010_00001_000_00000_1100011;
    read_data1 = 10;
    read_data2 = 5;

    #10;

    $display("BEQ Not Equal: branch_taken = %b (Expected 0)", branch_taken);

////////////////////////////////////////////////////////////

    $display("------------------------------------------------");
    $display("Testbench Finished");

    $finish;

end

endmodule