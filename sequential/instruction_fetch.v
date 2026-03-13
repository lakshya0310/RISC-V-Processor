`define IMEM_SIZE 4096

module Instruction_Fetch_Stage(
    input clk,
    input reset,
    input Branch,         
    input Zero,             
    input [63:0] imm,       
    output [31:0] instr,    
    output [63:0] pc_out   
);

    wire [63:0] pc_next_wire;
    wire [63:0] pc_plus4;
    wire [63:0] branch_target;

    PC program_counter (
        .clk(clk),
        .reset(reset),
        .pc_in(pc_next_wire),
        .pc_out(pc_out)
    );

    Instruction_Memory imem (
        .addr(pc_out),
        .instr(instr)
    );

    PC_adder add4 (
        .pc(pc_out),
        .pc_4(pc_plus4)
    );

    PC_branchadder add_branch (
        .pc_curr(pc_out),
        .imm(imm),
        .branch_target(branch_target)
    );

    next_pc_mux mux (
        .Branch(Branch),
        .Zero(Zero),
        .pc_plus4(pc_plus4),
        .branch_target(branch_target),
        .next_pc(pc_next_wire)
    );

endmodule

module Instruction_Memory(
    input [63:0] addr,
    output [31:0] instr
);
    reg [7:0] mem [0:`IMEM_SIZE-1];

    initial begin
        $readmemh("instructions.txt", mem); 
    end

    assign instr = {mem[addr], mem[addr+1], mem[addr+2], mem[addr+3]};
endmodule