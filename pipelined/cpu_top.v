`timescale 1ns/1ps
`define IMEM_SIZE 4096
`define DMEM_SIZE 1024

`include "if_id.v"
`include "id_ex.v"
`include "ex_mem.v"
`include "mem_wb.v"
`include "hazard_detection.v"
`include "branch_flush.v"
`include "forwarding_unit.v"


module cpu_top_pipelined(
input clk,
input reset
);

////////////////////////////////////////////////////////////
/////////////////////// PC STAGE ///////////////////////////
////////////////////////////////////////////////////////////

reg [63:0] pc;

wire [63:0] pc_next;
wire [63:0] pc_plus4;

assign pc_plus4 = pc + 64'd4;

always @(posedge clk) begin
    if(reset)
        pc <= 0;
    else if(!stall)
        pc <= pc_next;
end

////////////////////////////////////////////////////////////
//////////////////// INSTRUCTION FETCH /////////////////////
////////////////////////////////////////////////////////////

wire [31:0] instruction;

instruction_fetch IF(

.clk(clk),
.reset(reset),
.addr(pc),
.instruction(instruction)

);

////////////////////////////////////////////////////////////
//////////////////// IF / ID PIPELINE //////////////////////
////////////////////////////////////////////////////////////

wire [63:0] IF_ID_pc;
wire [31:0] IF_ID_instruction;

IF_ID if_id(

.clk(clk),
.reset(reset),
.stall(stall),
.flush(flush_IF_ID),

.pc_in(pc),
.instruction_in(instruction),

.pc_out(IF_ID_pc),
.instruction_out(IF_ID_instruction)

);

////////////////////////////////////////////////////////////
////////////////////// ID STAGE ////////////////////////////
////////////////////////////////////////////////////////////

wire [6:0] opcode;
wire [4:0] rs1;
wire [4:0] rs2;
wire [4:0] rd;

assign opcode = IF_ID_instruction[6:0];
assign rs1 = IF_ID_instruction[19:15];
assign rs2 = IF_ID_instruction[24:20];
assign rd  = IF_ID_instruction[11:7];

////////////////////////////////////////////////////////////
/////////////////////// IMMEDIATE //////////////////////////
////////////////////////////////////////////////////////////

wire [63:0] imm_I;
wire [63:0] imm_S;
wire [63:0] imm_B;
wire [63:0] immediate;

assign imm_I = {{52{IF_ID_instruction[31]}}, IF_ID_instruction[31:20]};
assign imm_S = {{52{IF_ID_instruction[31]}}, IF_ID_instruction[31:25], IF_ID_instruction[11:7]};
assign imm_B = {{51{IF_ID_instruction[31]}}, IF_ID_instruction[31], IF_ID_instruction[7], IF_ID_instruction[30:25], IF_ID_instruction[11:8],1'b0};

assign immediate =
(opcode == 7'b0000011) ? imm_I :
(opcode == 7'b0100011) ? imm_S :
(opcode == 7'b1100011) ? imm_B :
imm_I;

////////////////////////////////////////////////////////////
//////////////////// CONTROL UNIT //////////////////////////
////////////////////////////////////////////////////////////

wire Branch;
wire MemRead;
wire MemWrite;
wire MemtoReg;
wire RegWrite;
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

////////////////////////////////////////////////////////////
//////////////////// REGISTER FILE /////////////////////////
////////////////////////////////////////////////////////////


wire [63:0] read_data1;
wire [63:0] read_data2;

wire [63:0] rf_read_data1;
wire [63:0] rf_read_data2;

register_file RF(

.clk(clk),
.reset(reset),

.read_reg1(rs1),
.read_reg2(rs2),

.write_reg(MEM_WB_rd),
.write_data(write_back_data),

.regwrite(MEM_WB_RegWrite),

.read_data1(rf_read_data1),
.read_data2(rf_read_data2)

);

// WB → ID forwarding

assign read_data1 =
    (MEM_WB_RegWrite && (MEM_WB_rd != 0) && (MEM_WB_rd == rs1)) ?
        write_back_data :
        rf_read_data1;

assign read_data2 =
    (MEM_WB_RegWrite && (MEM_WB_rd != 0) && (MEM_WB_rd == rs2)) ?
        write_back_data :
        rf_read_data2;
// WB → ID forwarding

assign read_data1 =
    (MEM_WB_RegWrite && (MEM_WB_rd != 0) && (MEM_WB_rd == rs1)) ?
        write_back_data :
        rf_read_data1;

assign read_data2 =
    (MEM_WB_RegWrite && (MEM_WB_rd != 0) && (MEM_WB_rd == rs2)) ?
        write_back_data :
        rf_read_data2;

////////////////////////////////////////////////////////////
//////////////////// HAZARD DETECTION //////////////////////
////////////////////////////////////////////////////////////

wire stall;

hazard_detection HD(

.ID_EX_MemRead(ID_EX_MemRead),
.ID_EX_rd(ID_EX_rd),

.IF_ID_rs1(rs1),
.IF_ID_rs2(rs2),

.stall(stall)

);

////////////////////////////////////////////////////////////
//////////////////// ID / EX PIPELINE //////////////////////
////////////////////////////////////////////////////////////

wire [63:0] ID_EX_pc;
wire [31:0] ID_EX_instruction;
wire [63:0] ID_EX_read_data1;
wire [63:0] ID_EX_read_data2;
wire [63:0] ID_EX_immediate;

wire [4:0] ID_EX_rs1;
wire [4:0] ID_EX_rs2;
wire [4:0] ID_EX_rd;

wire ID_EX_MemRead;
wire ID_EX_MemWrite;
wire ID_EX_MemtoReg;
wire ID_EX_RegWrite;
wire [1:0] ID_EX_ALUOp;
wire ID_EX_ALUSrc;
wire ID_EX_Branch;

ID_EX id_ex(

.clk(clk),
.reset(reset),
.stall(stall),
.flush(flush_ID_EX),

.pc_in(IF_ID_pc),
.instruction_in(IF_ID_instruction),
.read_data1_in(read_data1),
.read_data2_in(read_data2),
.immediate_in(immediate),

.rs1_in(rs1),
.rs2_in(rs2),
.rd_in(rd),

.MemRead_in(MemRead),
.MemWrite_in(MemWrite),
.MemtoReg_in(MemtoReg),
.RegWrite_in(RegWrite),
.ALUOp_in(ALUOp),
.ALUSrc_in(ALUSrc),
.Branch_in(Branch),

.pc_out(ID_EX_pc),
.instruction_out(ID_EX_instruction),
.read_data1_out(ID_EX_read_data1),
.read_data2_out(ID_EX_read_data2),
.immediate_out(ID_EX_immediate),

.rs1_out(ID_EX_rs1),
.rs2_out(ID_EX_rs2),
.rd_out(ID_EX_rd),

.MemRead_out(ID_EX_MemRead),
.MemWrite_out(ID_EX_MemWrite),
.MemtoReg_out(ID_EX_MemtoReg),
.RegWrite_out(ID_EX_RegWrite),
.ALUOp_out(ID_EX_ALUOp),
.ALUSrc_out(ID_EX_ALUSrc),
.Branch_out(ID_EX_Branch)

);

////////////////////////////////////////////////////////////
//////////////////// EXECUTE STAGE /////////////////////////
////////////////////////////////////////////////////////////

wire [63:0] alu_result;
wire zero_flag;
wire branch_taken;
wire [63:0] fwd_rs2_val;

wire flush_IF_ID;
wire flush_ID_EX;

wire EX_MemRead;
wire EX_MemWrite;
wire EX_MemtoReg;
wire EX_RegWrite;

execute_stage EX(

.instruction(ID_EX_instruction),

// control signals from ID/EX pipeline
.Branch(ID_EX_Branch),
.MemRead(ID_EX_MemRead),
.MemWrite(ID_EX_MemWrite),
.MemtoReg(ID_EX_MemtoReg),
.RegWrite(ID_EX_RegWrite),
.ALUOp(ID_EX_ALUOp),
.ALUSrc(ID_EX_ALUSrc),

// register operands
.read_data1(ID_EX_read_data1),
.read_data2(ID_EX_read_data2),
.immediate(ID_EX_immediate),

// forwarding
.ID_EX_rs1(ID_EX_rs1),
.ID_EX_rs2(ID_EX_rs2),
.EX_MEM_rd(EX_MEM_rd),
.MEM_WB_rd(MEM_WB_rd),

.EX_MEM_RegWrite(EX_MEM_RegWrite),
.MEM_WB_RegWrite(MEM_WB_RegWrite),

.EX_MEM_alu_result(EX_MEM_alu_result),
.MEM_WB_write_data(write_back_data),

// outputs
.alu_result(alu_result),
.zero_flag(zero_flag),
.branch_taken(branch_taken),

.MemRead_out(EX_MemRead),
.MemWrite_out(EX_MemWrite),
.MemtoReg_out(EX_MemtoReg),
.RegWrite_out(EX_RegWrite),

.fwd_rs2_val(fwd_rs2_val)

);
branch_flush BF(

.branch_taken(branch_taken),

.flush_IF_ID(flush_IF_ID),
.flush_ID_EX(flush_ID_EX)

);

////////////////////////////////////////////////////////////
//////////////////// EX / MEM PIPELINE /////////////////////
////////////////////////////////////////////////////////////

wire [63:0] EX_MEM_alu_result;
wire [63:0] EX_MEM_write_data;
wire [4:0] EX_MEM_rd;

wire EX_MEM_MemRead;
wire EX_MEM_MemWrite;
wire EX_MEM_MemtoReg;
wire EX_MEM_RegWrite;

EX_MEM ex_mem(

.clk(clk),
.reset(reset),

.alu_result_in(alu_result),
.write_data_in(fwd_rs2_val),
.rd_in(ID_EX_rd),

.MemRead_in(EX_MemRead),
.MemWrite_in(EX_MemWrite),
.MemtoReg_in(EX_MemtoReg),
.RegWrite_in(EX_RegWrite),

.alu_result_out(EX_MEM_alu_result),
.write_data_out(EX_MEM_write_data),
.rd_out(EX_MEM_rd),

.MemRead_out(EX_MEM_MemRead),
.MemWrite_out(EX_MEM_MemWrite),
.MemtoReg_out(EX_MEM_MemtoReg),
.RegWrite_out(EX_MEM_RegWrite)

);

////////////////////////////////////////////////////////////
//////////////////// MEMORY STAGE //////////////////////////
////////////////////////////////////////////////////////////

wire [63:0] mem_read_data;

data_mem #(.DMEM_SIZE(`DMEM_SIZE)) DM(

.clk(clk),
.reset(reset),

.address(EX_MEM_alu_result),
.write_data(EX_MEM_write_data),

.MemRead(EX_MEM_MemRead),
.MemWrite(EX_MEM_MemWrite),

.read_data(mem_read_data)

);

////////////////////////////////////////////////////////////
//////////////////// MEM / WB PIPELINE /////////////////////
////////////////////////////////////////////////////////////

wire [63:0] MEM_WB_mem_data;
wire [63:0] MEM_WB_alu_result;
wire [4:0] MEM_WB_rd;

wire MEM_WB_MemtoReg;
wire MEM_WB_RegWrite;

MEM_WB mem_wb(

.clk(clk),
.reset(reset),

.mem_data_in(mem_read_data),
.alu_result_in(EX_MEM_alu_result),
.rd_in(EX_MEM_rd),

.MemtoReg_in(EX_MEM_MemtoReg),
.RegWrite_in(EX_MEM_RegWrite),

.mem_data_out(MEM_WB_mem_data),
.alu_result_out(MEM_WB_alu_result),
.rd_out(MEM_WB_rd),

.MemtoReg_out(MEM_WB_MemtoReg),
.RegWrite_out(MEM_WB_RegWrite)

);

////////////////////////////////////////////////////////////
//////////////////// WRITE BACK ////////////////////////////
////////////////////////////////////////////////////////////

wire [63:0] write_back_data;

assign write_back_data =
(MEM_WB_MemtoReg) ? MEM_WB_mem_data :
MEM_WB_alu_result;

////////////////////////////////////////////////////////////
//////////////////// NEXT PC LOGIC /////////////////////////
////////////////////////////////////////////////////////////

wire [63:0] branch_target;

assign branch_target = ID_EX_pc + ID_EX_immediate;

assign pc_next =
(branch_taken) ? branch_target :
pc_plus4;

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

    // control signals from ID/EX
    input Branch,
    input MemRead,
    input MemWrite,
    input MemtoReg,
    input RegWrite,
    input [1:0] ALUOp,
    input ALUSrc,

    // Forwarding inputs
    input [4:0] ID_EX_rs1,
    input [4:0] ID_EX_rs2,
    input [4:0] EX_MEM_rd,
    input [4:0] MEM_WB_rd,

    input EX_MEM_RegWrite,
    input MEM_WB_RegWrite,

    input [63:0] EX_MEM_alu_result,
    input [63:0] MEM_WB_write_data,

    output [63:0] alu_result,
    output zero_flag,
    output branch_taken,

    // control outputs forwarded to EX/MEM
    output MemRead_out,
    output MemWrite_out,
    output MemtoReg_out,
    output RegWrite_out,

    output [63:0] fwd_rs2_val
);

///////////////////////////////////////////////////////////
//////////////////// FORWARDING ///////////////////////////
///////////////////////////////////////////////////////////

reg [1:0] ForwardA;
reg [1:0] ForwardB;

always @(*) begin

    if (EX_MEM_RegWrite && (EX_MEM_rd != 0) && (EX_MEM_rd == ID_EX_rs1))
        ForwardA = 2'b10;
    else if (MEM_WB_RegWrite && (MEM_WB_rd != 0) && (MEM_WB_rd == ID_EX_rs1))
        ForwardA = 2'b01;
    else
        ForwardA = 2'b00;

    if (EX_MEM_RegWrite && (EX_MEM_rd != 0) && (EX_MEM_rd == ID_EX_rs2))
        ForwardB = 2'b10;
    else if (MEM_WB_RegWrite && (MEM_WB_rd != 0) && (MEM_WB_rd == ID_EX_rs2))
        ForwardB = 2'b01;
    else
        ForwardB = 2'b00;

end


wire [63:0] op_a =
        (ForwardA == 2'b10) ? EX_MEM_alu_result :
        (ForwardA == 2'b01) ? MEM_WB_write_data :
                              read_data1;

assign fwd_rs2_val =
        (ForwardB == 2'b10) ? EX_MEM_alu_result :
        (ForwardB == 2'b01) ? MEM_WB_write_data :
                              read_data2;


///////////////////////////////////////////////////////////
//////////////////// ALU INPUT ////////////////////////////
///////////////////////////////////////////////////////////

wire [63:0] alu_in2;

assign alu_in2 = (ALUSrc) ? immediate : fwd_rs2_val;


///////////////////////////////////////////////////////////
//////////////////// ALU CONTROL //////////////////////////
///////////////////////////////////////////////////////////

wire [2:0] funct3 = instruction[14:12];
wire [6:0] funct7 = instruction[31:25];

wire [3:0] alu_ctrl;

alu_control AC(
    .ALUOp(ALUOp),
    .funct3(funct3),
    .funct7(funct7),
    .ALUControl(alu_ctrl)
);


///////////////////////////////////////////////////////////
//////////////////// ALU //////////////////////////////////
///////////////////////////////////////////////////////////

wire cout;
wire carry_flag;
wire overflow_flag;

alu_64_bit ALU(
    .a(op_a),
    .b(alu_in2),
    .opcode(alu_ctrl),
    .result(alu_result),
    .cout(cout),
    .carry_flag(carry_flag),
    .overflow_flag(overflow_flag),
    .zero_flag(zero_flag)
);


///////////////////////////////////////////////////////////
//////////////////// BRANCH LOGIC /////////////////////////
///////////////////////////////////////////////////////////

wire signed [63:0] s_r1 = op_a;
wire signed [63:0] s_r2 = fwd_rs2_val;

wire slt_signed = (s_r1 < s_r2);
wire slt_unsigned = (op_a < fwd_rs2_val);

wire branch_condition =
       ((funct3 == 3'b000) & (op_a == fwd_rs2_val)) |
       ((funct3 == 3'b001) & (op_a != fwd_rs2_val)) |
       ((funct3 == 3'b100) & slt_signed) |
       ((funct3 == 3'b101) & ~slt_signed) |
       ((funct3 == 3'b110) & slt_unsigned) |
       ((funct3 == 3'b111) & ~slt_unsigned);

assign branch_taken = Branch & branch_condition;


///////////////////////////////////////////////////////////
//////////////// CONTROL PASS THROUGH /////////////////////
///////////////////////////////////////////////////////////

assign MemRead_out  = MemRead;
assign MemWrite_out = MemWrite;
assign MemtoReg_out = MemtoReg;
assign RegWrite_out = RegWrite;

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

