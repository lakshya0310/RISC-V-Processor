module forwarding_unit(

    input EX_MEM_RegWrite,
    input MEM_WB_RegWrite,

    input [4:0] EX_MEM_rd,
    input [4:0] MEM_WB_rd,

    input [4:0] ID_EX_rs1,
    input [4:0] ID_EX_rs2,

    output reg [1:0] ForwardA,
    output reg [1:0] ForwardB
);

always @(*) begin

ForwardA = 2'b00;
ForwardB = 2'b00;

// EX hazard (MEM → EX)

if(EX_MEM_RegWrite &&
   (EX_MEM_rd != 0) &&
   (EX_MEM_rd == ID_EX_rs1))
    ForwardA = 2'b10;

if(EX_MEM_RegWrite &&
   (EX_MEM_rd != 0) &&
   (EX_MEM_rd == ID_EX_rs2))
    ForwardB = 2'b10;


// MEM hazard (WB → EX)

if(MEM_WB_RegWrite &&
   (MEM_WB_rd != 0) &&
   !(EX_MEM_RegWrite &&
     (EX_MEM_rd != 0) &&
     (EX_MEM_rd == ID_EX_rs1)) &&
   (MEM_WB_rd == ID_EX_rs1))
    ForwardA = 2'b01;


if(MEM_WB_RegWrite &&
   (MEM_WB_rd != 0) &&
   !(EX_MEM_RegWrite &&
     (EX_MEM_rd != 0) &&
     (EX_MEM_rd == ID_EX_rs2)) &&
   (MEM_WB_rd == ID_EX_rs2))
    ForwardB = 2'b01;

end

endmodule