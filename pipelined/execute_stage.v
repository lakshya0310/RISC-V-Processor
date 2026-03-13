

module execute_stage (

    // instruction fields
    input [31:0] instruction,

    // register values
    input [63:0] read_data1,
    input [63:0] read_data2,

    // immediate value
    input [63:0] immediate,

    input [4:0] ID_EX_rs1,
    input [4:0] ID_EX_rs2,

    input [63:0] EX_MEM_alu_result,
    input [63:0] MEM_WB_write_data,

    input [4:0] EX_MEM_rd,
    input [4:0] MEM_WB_rd,

    input EX_MEM_RegWrite,
    input MEM_WB_RegWrite,

    // outputs
    output [63:0] alu_result,
    output zero_flag,
    output branch_taken,

    // control outputs
    output MemRead,
    output MemWrite,
    output MemtoReg,
    output RegWrite,

    // NEW OUTPUT (for store forwarding)
    output [63:0] fwd_rs2_val

);

////////////////////////////////////////////////////////////
// Extract instruction fields
////////////////////////////////////////////////////////////

wire [6:0] opcode  = instruction[6:0];
wire [2:0] funct3  = instruction[14:12];
wire [6:0] funct7  = instruction[31:25];

////////////////////////////////////////////////////////////
// Control Unit
////////////////////////////////////////////////////////////

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

////////////////////////////////////////////////////////////
// ALU Control
////////////////////////////////////////////////////////////

wire [3:0] alu_control_signal;

alu_control ALUCTRL(

.ALUOp(ALUOp),
.funct3(funct3),
.funct7(funct7),
.ALUControl(alu_control_signal)

);

////////////////////////////////////////////////////////////
// Forwarding Unit
////////////////////////////////////////////////////////////

wire [1:0] ForwardA;
wire [1:0] ForwardB;

forwarding_unit FU(

.EX_MEM_RegWrite(EX_MEM_RegWrite),
.MEM_WB_RegWrite(MEM_WB_RegWrite),

.EX_MEM_rd(EX_MEM_rd),
.MEM_WB_rd(MEM_WB_rd),

.ID_EX_rs1(ID_EX_rs1),
.ID_EX_rs2(ID_EX_rs2),

.ForwardA(ForwardA),
.ForwardB(ForwardB)

);

////////////////////////////////////////////////////////////
// Forwarded ALU inputs
////////////////////////////////////////////////////////////

reg [63:0] alu_input1;
reg [63:0] forwardB_data;

always @(*) begin

case(ForwardA)

2'b00: alu_input1 = read_data1;
2'b10: alu_input1 = EX_MEM_alu_result;
2'b01: alu_input1 = MEM_WB_write_data;

default: alu_input1 = read_data1;

endcase

end

always @(*) begin

case(ForwardB)

2'b00: forwardB_data = read_data2;
2'b10: forwardB_data = EX_MEM_alu_result;
2'b01: forwardB_data = MEM_WB_write_data;

default: forwardB_data = read_data2;

endcase

end

////////////////////////////////////////////////////////////
// Forwarded store value (NEW FIX)
////////////////////////////////////////////////////////////

assign fwd_rs2_val = forwardB_data;

////////////////////////////////////////////////////////////
// ALU input mux
////////////////////////////////////////////////////////////

wire [63:0] alu_input2;

assign alu_input2 =
(ALUSrc) ? immediate :
forwardB_data;

////////////////////////////////////////////////////////////
// ALU
////////////////////////////////////////////////////////////

wire cout;
wire carry_flag;
wire overflow_flag;

alu_64_bit alu_inst(

.a(alu_input1),
.b(alu_input2),
.opcode(alu_control_signal),

.result(alu_result),
.cout(cout),
.carry_flag(carry_flag),
.overflow_flag(overflow_flag),
.zero_flag(zero_flag)

);

////////////////////////////////////////////////////////////
// Branch logic
////////////////////////////////////////////////////////////

assign branch_taken =
Branch & zero_flag;

endmodule
