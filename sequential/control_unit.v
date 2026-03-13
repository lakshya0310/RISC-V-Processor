module control_unit (

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

    Branch   = 0;
    MemRead  = 0;
    MemtoReg = 0;
    ALUOp    = 2'b00;
    MemWrite = 0;
    ALUSrc   = 0;
    RegWrite = 0;

    case(opcode)

        // R-type: add, sub, and, or
        7'b0110011: begin
            RegWrite = 1;
            ALUSrc   = 0;
            ALUOp    = 2'b10;
        end

        // addi
        7'b0010011: begin
            RegWrite = 1;
            ALUSrc   = 1;
            ALUOp    = 2'b10;
        end

        // ld
        7'b0000011: begin
            RegWrite = 1;
            MemRead  = 1;
            MemtoReg = 1;
            ALUSrc   = 1;
            ALUOp    = 2'b00;
        end

        // sd
        7'b0100011: begin
            MemWrite = 1;
            ALUSrc   = 1;
            ALUOp    = 2'b00;
        end

        // beq
        7'b1100011: begin
            Branch = 1;
            ALUOp  = 2'b01;
        end

    endcase

end

endmodule