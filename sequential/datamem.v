module data_mem(
input wire clk,
input wire reset,
input wire[63:0]address,
input wire[63:0]write_data,
input wire MemRead,
input wire MemWrite,
output reg [63:0]read_data
);
reg[7:0]mem[0:1023];
integer  i;
always@(posedge clk)begin
if(reset)begin
for(i=0;i<1024;i=i+1)
mem[i]<=8'b0;
read_data<=64'b0;
end
else begin
if(MemRead==1)begin
read_data<={
mem[address+0],
mem[address+1],
mem[address+2],
mem[address+3],
mem[address+4],
mem[address+5],
mem[address+6],
mem[address+7]
};
end
if(MemWrite==1)begin
for( i=0;i<8;i=i+1)begin
mem[address+i]<=write_data[8*(8-i)-1:8*(8-i)-8];
end
end
end
end
endmodule

