module hazard_detection(

input ID_EX_MemRead,
input [4:0] ID_EX_rd,

input [4:0] IF_ID_rs1,
input [4:0] IF_ID_rs2,

output reg stall

);

always @(*) begin

if(ID_EX_MemRead &&
   ((ID_EX_rd == IF_ID_rs1) ||
    (ID_EX_rd == IF_ID_rs2)))
        stall = 1;
else
        stall = 0;

end

endmodule
