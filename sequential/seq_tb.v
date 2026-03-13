`timescale 1ns/1ps
`define DMEM_SIZE 1024

module seq_tb;

reg clk;
reg reset;

parameter MAX_CYCLES = 200;

integer i, j;
integer file_reg;
integer file_mem;
integer cycles;
reg [63:0] prev_pc;
reg stop_flag;
reg [63:0] word64;

// Instantiate CPU
cpu_top uut (
    .clk(clk),
    .reset(reset)
);

initial begin
    clk = 0;
    reset = 1;
    cycles = 0;
    prev_pc = 64'b0;
    stop_flag = 0;

    #20;
    reset = 0;

    $display("\n========= CPU EXECUTION TRACE =========\n");

    // ================= EXECUTION LOOP =================
    while (!stop_flag && cycles < MAX_CYCLES) begin
        @(posedge clk);

        // Stop if PC becomes unknown
        if (^uut.pc === 1'bx) begin
            $display("\n*** PC became unknown. Stopping simulation. ***\n");
            stop_flag = 1;
        end

        // Stop if infinite loop (PC not changing)
        else if (cycles > 0 && uut.pc === prev_pc) begin
            $display("\n*** PC did not change. Program finished. ***\n");
            stop_flag = 1;
        end

        // Stop on ECALL
        else if (uut.instruction == 32'h00100073) begin
            cycles = cycles + 1;
            $display("\n*** ECALL detected. Stopping simulation. ***\n");
            stop_flag = 1;
        end

        // Stop on null instruction
        else if (uut.instruction == 32'b0) begin
            cycles = cycles + 1;
            $display("\n*** Null instruction detected. Stopping simulation. ***\n");
            stop_flag = 1;
        end

        else begin
            cycles = cycles + 1;

            $display("--------------------------------------------------");
            $display("Cycle: %0d", cycles);
            $display("PC              = %016x", uut.pc);
            $display("Instruction     = %08x", uut.instruction);

            $display("opcode = %07b | rd = x%0d | rs1 = x%0d | rs2 = x%0d",
                     uut.instruction[6:0],
                     uut.instruction[11:7],
                     uut.instruction[19:15],
                     uut.instruction[24:20]);

            $display("ALU Result      = %016x", uut.alu_result);
            $display("Branch Taken    = %b", uut.branch_taken);
            $display("Branch Target   = %016x", uut.branch_target);

            $display("MemRead = %b | MemWrite = %b | RegWrite = %b",
                     uut.MemRead, uut.MemWrite, uut.regwrite);

            if (uut.regwrite)
                $display(">>> WRITE: x%0d = %016x",
                         uut.instruction[11:7],
                         uut.write_back_data);

            if (uut.MemWrite)
                $display(">>> STORE: Addr = %016x | Data = %016x",
                         uut.alu_result,
                         uut.read_data2);

            if (uut.MemRead)
                $display(">>> LOAD: Addr = %016x | Data = %016x",
                         uut.alu_result,
                         uut.mem_read_data);
        end

        prev_pc = uut.pc;
    end

    if (cycles >= MAX_CYCLES)
        $display("\n*** MAX_CYCLES reached. Stopping simulation. ***\n");

    $display("\n========= EXECUTION FINISHED =========\n");

    // ================= WRITE REGISTER FILE =================
    file_reg = $fopen("register_file.txt", "w");
    if (file_reg == 0) begin
        $display("ERROR: could not open register_file.txt");
        $finish;
    end

    for (i = 0; i < 32; i = i + 1)
        $fdisplay(file_reg, "%016x", uut.RF.regs[i]);

    $fdisplay(file_reg, "%0d", cycles);
    $fclose(file_reg);

    $display("Wrote register_file.txt (%0d cycles)", cycles);


    $finish;
end

// Clock generation
always #5 clk = ~clk;

endmodule

`timescale 1ns/1ps
`define IMEM_SIZE 4096
`define DMEM_SIZE 1024

module cpu_top(
    input wire clk,
    input wire reset
);


    wire [63:0] pc;

    
    wire [31:0] instruction;

    
    wire branch_taken;
    wire [63:0] branch_target;

   
    wire halt = (instruction == 32'b0) || (instruction == 32'h00100073);

   
    wire [63:0] pc_next = halt ? pc : (branch_taken ? branch_target : (pc + 64'd4));

   
    pc pc_inst(
        .clk(clk),
        .reset(reset),
        .pc_in(pc_next),
        .pc_out(pc)
    );

  
    instruction_fetch if_inst(
        .clk(clk),
        .reset(reset),
        .addr(pc),
        .instruction(instruction)
    );

  
    wire [6:0] opcode = instruction[6:0];
    wire [4:0] rs1    = instruction[19:15];
    wire [4:0] rs2    = instruction[24:20];
    wire [4:0] rd     = instruction[11:7];

   
    wire [63:0] imm_I = {{52{instruction[31]}}, instruction[31:20]};
    wire [63:0] imm_S = {{52{instruction[31]}}, instruction[31:25], instruction[11:7]};
    wire [63:0] imm_B = {{51{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};

    wire [63:0] immediate =
        (opcode == 7'b0000011) ? imm_I :
        (opcode == 7'b0100011) ? imm_S :
        (opcode == 7'b1100011) ? imm_B :
        imm_I;

   
    wire [63:0] read_data1, read_data2, write_back_data;
    wire regwrite;

    register_file RF(
        .clk(clk),
        .reset(reset),
        .read_reg1(rs1),
        .read_reg2(rs2),
        .write_reg(rd),
        .write_data(write_back_data),
        .regwrite(regwrite),
        .read_data1(read_data1),
        .read_data2(read_data2)
    );

   
    wire [63:0] alu_result;
    wire zero_flag;
    wire MemRead, MemWrite, MemtoReg;
    wire RegWrite_signal;

    execute_stage EX(
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
        .RegWrite(RegWrite_signal)
    );

    
    assign regwrite = RegWrite_signal;

    
    wire [63:0] mem_read_data;

    data_mem #(.DMEM_SIZE(`DMEM_SIZE)) DM(
        .clk(clk),
        .reset(reset),
        .address(alu_result),
        .write_data(read_data2),
        .MemRead(MemRead),
        .MemWrite(MemWrite),
        .read_data(mem_read_data)
    );

    assign write_back_data = (MemtoReg) ? mem_read_data : alu_result;

   
    assign branch_target = pc + imm_B;

endmodule



module pc(
    input wire clk,
    input wire reset,
    input wire [63:0] pc_in,
    output reg [63:0] pc_out
);
always @(posedge clk) begin
    if (reset)
        pc_out <= 64'b0;
    else
        pc_out <= pc_in;
end
endmodule



module instruction_fetch(
    input wire clk,              
    input wire reset,
    input wire [63:0] addr,
    output wire [31:0] instruction
);
  
    reg [7:0] instruction_mem [0:`IMEM_SIZE-1];

    initial begin
       
        $readmemh("instructions.txt", instruction_mem);
    end

   
    wire [11:0] addr_index = addr[11:0];

   
    assign instruction = {
        instruction_mem[addr_index],
        instruction_mem[addr_index + 1],
        instruction_mem[addr_index + 2],
        instruction_mem[addr_index + 3]
    };

endmodule



module register_file(
    input  wire        clk,
    input  wire        reset,
    input  wire [4:0]  read_reg1,
    input  wire [4:0]  read_reg2,
    input  wire [4:0]  write_reg,
    input  wire [63:0] write_data,
    input  wire        regwrite,
    output wire [63:0] read_data1,
    output wire [63:0] read_data2
);
    reg [63:0] regs [31:0];
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 64'b0;
        end
        else if (regwrite && write_reg != 5'd0)
            regs[write_reg] <= write_data;
    end
    assign read_data1 = (read_reg1 == 5'd0) ? 64'b0 : regs[read_reg1];
    assign read_data2 = (read_reg2 == 5'd0) ? 64'b0 : regs[read_reg2];
endmodule



module data_mem #(
    parameter integer DMEM_SIZE = 1024
) (
    input  wire        clk,
    input  wire        reset,
    input  wire [63:0] address,
    input  wire [63:0] write_data,
    input  wire        MemRead,
    input  wire        MemWrite,
    output wire [63:0] read_data
);

    reg [7:0] mem [0:DMEM_SIZE-1];
    integer i;

   
    localparam ADDR_WIDTH = $clog2(DMEM_SIZE);
    wire [ADDR_WIDTH-1:0] addr = address[ADDR_WIDTH-1:0];

   
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < DMEM_SIZE; i = i + 1)
                mem[i] <= 8'b0;
        end
        else begin
            if (MemWrite && (addr <= (DMEM_SIZE - 8))) begin
                mem[addr + 0] <= write_data[63:56];
                mem[addr + 1] <= write_data[55:48];
                mem[addr + 2] <= write_data[47:40];
                mem[addr + 3] <= write_data[39:32];
                mem[addr + 4] <= write_data[31:24];
                mem[addr + 5] <= write_data[23:16];
                mem[addr + 6] <= write_data[15:8];
                mem[addr + 7] <= write_data[7:0];
            end
        end
    end

  
    wire in_range = (addr <= (DMEM_SIZE - 8));
    assign read_data = (MemRead && in_range) ?
                       { mem[addr + 0],
                         mem[addr + 1],
                         mem[addr + 2],
                         mem[addr + 3],
                         mem[addr + 4],
                         mem[addr + 5],
                         mem[addr + 6],
                         mem[addr + 7] }
                       : 64'b0;

endmodule



module execute_stage(
    input [31:0] instruction,
    input [63:0] read_data1,
    input [63:0] read_data2,
    input [63:0] immediate,
    output [63:0] alu_result,
    output zero_flag,
    output branch_taken,
    output MemRead,
    output MemWrite,
    output MemtoReg,
    output RegWrite
);
    wire [6:0] opcode = instruction[6:0];
    wire [2:0] funct3 = instruction[14:12];
    wire [6:0] funct7 = instruction[31:25];

    wire Branch;
    wire [1:0] ALUOp;
    wire ALUSrc;

    control_unit CU(
        .opcode(opcode),
        .Branch(Branch),
        .MemRead(MemRead),
        .MemtoReg(MemtoReg),
        .ALUOp(ALUOp),
        .MemWrite(MemWrite),
        .ALUSrc(ALUSrc),
        .RegWrite(RegWrite)
    );

    wire [63:0] alu_in2;
    alusrc_mux AM(
        .ALUSrc(ALUSrc),
        .read_data2(read_data2),
        .immediate(immediate),
        .alu_input2(alu_in2)
    );

    wire [3:0] alu_ctrl;
    alu_control AC(
        .ALUOp(ALUOp),
        .funct3(funct3),
        .funct7(funct7),
        .ALUControl(alu_ctrl)
    );

    wire cout_flag;
    wire carry_flag_net;
    wire overflow_flag_net;
    alu_64_bit ALU(
        .a(read_data1),
        .b(alu_in2),
        .opcode(alu_ctrl),
        .result(alu_result),
        .cout(cout_flag),
        .carry_flag(carry_flag_net),
        .overflow_flag(overflow_flag_net),
        .zero_flag()
    );

    
    wire zero_flag_internal;
    assign zero_flag_internal = (alu_result == 64'b0);
    assign zero_flag = zero_flag_internal;

   
    wire signed [63:0] s_r1 = read_data1;
    wire signed [63:0] s_r2 = read_data2;
    wire slt_signed = (s_r1 < s_r2);
    wire slt_unsigned = (read_data1 < read_data2);

    wire is_beq  = (funct3 == 3'b000);
    wire is_bne  = (funct3 == 3'b001);
    wire is_blt  = (funct3 == 3'b100);
    wire is_bge  = (funct3 == 3'b101);
    wire is_bltu = (funct3 == 3'b110);
    wire is_bgeu = (funct3 == 3'b111);

    wire branch_condition = 
           (is_beq  & (read_data1 == read_data2)) |
           (is_bne  & (read_data1 != read_data2)) |
           (is_blt  & slt_signed) |
           (is_bge  & ~slt_signed) |
           (is_bltu & slt_unsigned) |
           (is_bgeu & ~slt_unsigned);

    assign branch_taken = Branch & branch_condition;

endmodule



module control_unit(
    input [6:0] opcode,
    output reg Branch,
    output reg MemRead,
    output reg MemtoReg,
    output reg [1:0] ALUOp,
    output reg MemWrite,
    output reg ALUSrc,
    output reg RegWrite
);
always @(*) begin
    case (opcode)
        7'b0110011: begin
            Branch = 0; MemRead = 0; MemtoReg = 0;
            ALUOp = 2'b10; MemWrite = 0;
            ALUSrc = 0; RegWrite = 1;
        end
        7'b0000011: begin
            Branch = 0; MemRead = 1; MemtoReg = 1;
            ALUOp = 2'b00; MemWrite = 0;
            ALUSrc = 1; RegWrite = 1;
        end
        7'b0100011: begin
            Branch = 0; MemRead = 0; MemtoReg = 0;
            ALUOp = 2'b00; MemWrite = 1;
            ALUSrc = 1; RegWrite = 0;
        end
        7'b1100011: begin
            Branch = 1; MemRead = 0; MemtoReg = 0;
            ALUOp = 2'b01; MemWrite = 0;
            ALUSrc = 0; RegWrite = 0;
        end
        7'b0010011: begin
            Branch = 0; MemRead = 0; MemtoReg = 0;
            ALUOp = 2'b00; MemWrite = 0;
            ALUSrc = 1; RegWrite = 1;
        end
        default: begin
            Branch = 0; MemRead = 0; MemtoReg = 0;
            ALUOp = 2'b00; MemWrite = 0;
            ALUSrc = 0; RegWrite = 0;
        end
    endcase
end
endmodule



module alu_control(
    input [1:0] ALUOp,
    input [2:0] funct3,
    input [6:0] funct7,
    output reg [3:0] ALUControl
);
localparam ADD_Oper  = 4'b0000;
localparam SLL_Oper  = 4'b0001;
localparam SLT_Oper  = 4'b0010;
localparam SLTU_Oper = 4'b0011;
localparam XOR_Oper  = 4'b0100;
localparam SRL_Oper  = 4'b0101;
localparam OR_Oper   = 4'b0110;
localparam AND_Oper  = 4'b0111;
localparam SUB_Oper  = 4'b1000;
localparam SRA_Oper  = 4'b1101;
always @(*) begin
    case (ALUOp)
        2'b00: ALUControl = ADD_Oper;
        2'b01: ALUControl = SUB_Oper;
        2'b10: begin
            case (funct3)
                3'b000: begin
                    if (funct7 == 7'b0100000)
                        ALUControl = SUB_Oper;
                    else
                        ALUControl = ADD_Oper;
                end
                3'b111: ALUControl = AND_Oper;
                3'b110: ALUControl = OR_Oper;
                3'b100: ALUControl = XOR_Oper;
                3'b001: ALUControl = SLL_Oper;
                3'b101: begin
                    if (funct7 == 7'b0100000)
                        ALUControl = SRA_Oper;
                    else
                        ALUControl = SRL_Oper;
                end
                default: ALUControl = ADD_Oper;
            endcase
        end
        default: ALUControl = ADD_Oper;
    endcase
end
endmodule


module alusrc_mux(
    input wire ALUSrc,
    input wire [63:0] read_data2,
    input wire [63:0] immediate,
    output wire [63:0] alu_input2
);
assign alu_input2 = (ALUSrc) ? immediate : read_data2;
endmodule


module mux2to1 (
    input a, b, sel,
    output out
);
    wire nsel, temp1, temp2;
    not (nsel, sel);
    and (temp1, a, nsel);
    and (temp2, b, sel);
    or  (out, temp1, temp2);
endmodule

module mux2to1_64(
    input  [63:0] a, b,
    input         sel,
    output [63:0] out
);
    assign out = sel ? b : a;
endmodule

module and_64bit(
    input [63:0] a,
    input [63:0] b,
    output [63:0] z
);
    genvar i;
    generate
        for(i = 0; i < 64; i = i + 1) begin : and_64
            and(z[i], a[i], b[i]);
        end
    endgenerate
endmodule

module or_64bit(
    input [63:0] a, b,
    output [63:0] z
);
    genvar i;
    generate
        for(i = 0; i < 64; i = i + 1) begin : or_64
            or(z[i], a[i], b[i]);
        end
    endgenerate
endmodule

module xor_64bit(
    input [63:0] a, b,
    output [63:0] z
);
    genvar i;
    generate
        for(i = 0; i < 64; i = i + 1) begin : xor_64
            xor(z[i], a[i], b[i]);
        end
    endgenerate
endmodule

module fulladder(
    output sum,
    output cout,
    input a, b, cin
);
    wire p, g, t;
    xor (p, a, b);
    xor (sum, p, cin);
    and (g, a, b);
    and (t, p, cin);
    or  (cout, g, t);
endmodule

module adder_subtractor_64bit(
    output [63:0] sum,
    output cout,
    input signed [63:0] a,
    input signed [63:0] b,
    input mode  // 0: addition, 1: subtraction
);
    wire [63:0] b_mode;
    wire cin;
    wire [64:0] carry;
    assign cin = mode;
    assign carry[0] = cin;
    genvar i;
    generate
        for(i = 0; i < 64; i = i + 1) begin : fulladder_loop
            xor(b_mode[i], b[i], cin);
            fulladder fa(
                .sum(sum[i]),
                .cout(carry[i+1]),
                .a(a[i]),
                .b(b_mode[i]),
                .cin(carry[i])
            );
        end
    endgenerate
    assign cout = carry[64];
endmodule

module slt_sltu_64bit(
    input [63:0] a, b,
    output slt,
    output sltu
);
    wire [63:0] difference;
    wire cout;
    adder_subtractor_64bit sub_inst(
        .a(a),
        .b(b),
        .mode(1'b1),
        .sum(difference),
        .cout(cout)
    );
    assign slt  = difference[63];
    assign sltu = ~cout;
endmodule

module sll_64bit (
    input [63:0] A,
    input [4:0] shift,
    output [63:0] Out
);
    wire [63:0] stage0, stage1, stage2, stage3, stage4;
    genvar i;
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage0_loop
            wire in0, in1;
            assign in0 = A[i];
            assign in1 = (i == 0) ? 1'b0 : A[i-1];
            mux2to1 mux0 (.a(in0), .b(in1), .sel(shift[0]), .out(stage0[i]));
        end
    endgenerate
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage1_loop
            wire in0, in1;
            assign in0 = stage0[i];
            assign in1 = (i < 2) ? 1'b0 : stage0[i-2];
            mux2to1 mux1 (.a(in0), .b(in1), .sel(shift[1]), .out(stage1[i]));
        end
    endgenerate
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage2_loop
            wire in0, in1;
            assign in0 = stage1[i];
            assign in1 = (i < 4) ? 1'b0 : stage1[i-4];
            mux2to1 mux2 (.a(in0), .b(in1), .sel(shift[2]), .out(stage2[i]));
        end
    endgenerate
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage3_loop
            wire in0, in1;
            assign in0 = stage2[i];
            assign in1 = (i < 8) ? 1'b0 : stage2[i-8];
            mux2to1 mux3 (.a(in0), .b(in1), .sel(shift[3]), .out(stage3[i]));
        end
    endgenerate
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage4_loop
            wire in0, in1;
            assign in0 = stage3[i];
            assign in1 = (i < 16) ? 1'b0 : stage3[i-16];
            mux2to1 mux4 (.a(in0), .b(in1), .sel(shift[4]), .out(stage4[i]));
        end
    endgenerate
    assign Out = stage4;
endmodule

module srl_64bit (
    input [63:0] A,
    input [4:0] shift,
    output [63:0] Out
);
    wire [63:0] stage0, stage1, stage2, stage3, stage4;
    genvar i;
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage0_loop
            wire in0, in1;
            assign in0 = A[i];
            assign in1 = (i < 63) ? A[i+1] : 1'b0;
            mux2to1 mux0 (.a(in0), .b(in1), .sel(shift[0]), .out(stage0[i]));
        end
    endgenerate
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage1_loop
            wire in0, in1;
            assign in0 = stage0[i];
            assign in1 = (i < 62) ? stage0[i+2] : 1'b0;
            mux2to1 mux1 (.a(in0), .b(in1), .sel(shift[1]), .out(stage1[i]));
        end
    endgenerate
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage2_loop
            wire in0, in1;
            assign in0 = stage1[i];
            assign in1 = (i < 60) ? stage1[i+4] : 1'b0;
            mux2to1 mux2 (.a(in0), .b(in1), .sel(shift[2]), .out(stage2[i]));
        end
    endgenerate
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage3_loop
            wire in0, in1;
            assign in0 = stage2[i];
            assign in1 = (i < 56) ? stage2[i+8] : 1'b0;
            mux2to1 mux3 (.a(in0), .b(in1), .sel(shift[3]), .out(stage3[i]));
        end
    endgenerate
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage4_loop
            wire in0, in1;
            assign in0 = stage3[i];
            assign in1 = (i < 48) ? stage3[i+16] : 1'b0;
            mux2to1 mux4 (.a(in0), .b(in1), .sel(shift[4]), .out(stage4[i]));
        end
    endgenerate
    assign Out = stage4;
endmodule

module sra_64bit (
    input [63:0] A,
    input [4:0] shift,
    output [63:0] Out
);
    wire [63:0] stage0, stage1, stage2, stage3, stage4;
    genvar i;
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage0_loop
            wire in0, in1;
            assign in0 = A[i];
            assign in1 = (i < 63) ? A[i+1] : A[63];
            mux2to1 mux0 (.a(in0), .b(in1), .sel(shift[0]), .out(stage0[i]));
        end
    endgenerate
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage1_loop
            wire in0, in1;
            assign in0 = stage0[i];
            assign in1 = (i < 62) ? stage0[i+2] : stage0[63];
            mux2to1 mux1 (.a(in0), .b(in1), .sel(shift[1]), .out(stage1[i]));
        end
    endgenerate
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage2_loop
            wire in0, in1;
            assign in0 = stage1[i];
            assign in1 = (i < 60) ? stage1[i+4] : stage1[63];
            mux2to1 mux2 (.a(in0), .b(in1), .sel(shift[2]), .out(stage2[i]));
        end
    endgenerate
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage3_loop
            wire in0, in1;
            assign in0 = stage2[i];
            assign in1 = (i < 56) ? stage2[i+8] : stage2[63];
            mux2to1 mux3 (.a(in0), .b(in1), .sel(shift[3]), .out(stage3[i]));
        end
    endgenerate
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage4_loop
            wire in0, in1;
            assign in0 = stage3[i];
            assign in1 = (i < 48) ? stage3[i+16] : stage3[63];
            mux2to1 mux4 (.a(in0), .b(in1), .sel(shift[4]), .out(stage4[i]));
        end
    endgenerate
    assign Out = stage4;
endmodule


module alu_64_bit (
    input  [63:0] a,
    input  [63:0] b,
    input  [3:0]  opcode,
    output reg [63:0] result,
    output        cout,
    output reg    carry_flag,
    output reg    overflow_flag,
    output reg    zero_flag
);

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

    wire [63:0] add_result, sub_result;
    wire [63:0] sll_result, srl_result, sra_result;
    wire [63:0] and_result, or_result, xor_result;
    wire        slt_result, sltu_result;
    wire        add_cout, sub_cout;

    adder_subtractor_64bit add_inst (
        .a(a),
        .b(b),
        .mode(1'b0),
        .sum(add_result),
        .cout(add_cout)
    );

    adder_subtractor_64bit sub_inst (
        .a(a),
        .b(b),
        .mode(1'b1),
        .sum(sub_result),
        .cout(sub_cout)
    );

    and_64bit and_inst (.a(a), .b(b), .z(and_result));
    or_64bit  or_inst  (.a(a), .b(b), .z(or_result));
    xor_64bit xor_inst (.a(a), .b(b), .z(xor_result));

    sll_64bit sll_inst (.A(a), .shift(b[4:0]), .Out(sll_result));
    srl_64bit srl_inst (.A(a), .shift(b[4:0]), .Out(srl_result));
    sra_64bit sra_inst (.A(a), .shift(b[4:0]), .Out(sra_result));

    slt_sltu_64bit slt_inst (
        .a(a),
        .b(b),
        .slt(slt_result),
        .sltu(sltu_result)
    );

    always @(*) begin
        carry_flag    = 1'b0;
        overflow_flag = 1'b0;

        case (opcode)
            ADD_Oper: begin
                result = add_result;
                carry_flag = add_cout;
                overflow_flag = (~(a[63] ^ b[63])) & (a[63] ^ result[63]);
            end

            SUB_Oper: begin
                result = sub_result;
                carry_flag = sub_cout;
                overflow_flag = ((a[63] ^ b[63])) & (a[63] ^ result[63]);
            end

            AND_Oper: result = and_result;
            OR_Oper:  result = or_result;
            XOR_Oper: result = xor_result;

            SLL_Oper: result = sll_result;
            SRL_Oper: result = srl_result;
            SRA_Oper: result = sra_result;

            SLT_Oper:  result = {{63{1'b0}}, slt_result};
            SLTU_Oper: result = {{63{1'b0}}, sltu_result};

            default: result = 64'b0;
        endcase
    end

    assign cout = carry_flag;

    always @(*) begin
        zero_flag = (result == 64'b0);
    end

endmodule

