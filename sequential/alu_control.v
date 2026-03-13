module alu_control (

    input [1:0] ALUOp,
    input [2:0] funct3,
    input [6:0] funct7,

    output reg [3:0] ALUControl

);

always @(*) begin

    case(ALUOp)

        // ld, sd → ADD
        2'b00: ALUControl = 4'b0000;

        // beq → SUB
        2'b01: ALUControl = 4'b1000;

        // R-type and I-type
        2'b10: begin

            case(funct3)

                // ADD / SUB / ADDI
                3'b000: begin
                    if(funct7 == 7'b0100000)
                        ALUControl = 4'b1000; // SUB
                    else
                        ALUControl = 4'b0000; // ADD, ADDI
                end

                // AND
                3'b111: ALUControl = 4'b0111;

                // OR
                3'b110: ALUControl = 4'b0110;

                default: ALUControl = 4'b0000;

            endcase

        end

        default: ALUControl = 4'b0000;

    endcase

end

endmodule