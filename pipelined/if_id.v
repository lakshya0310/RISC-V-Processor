module IF_ID(

input clk,
input reset,
input stall,
input flush,

input [63:0] pc_in,
input [31:0] instruction_in,

output reg [63:0] pc_out,
output reg [31:0] instruction_out

);

always @(posedge clk) begin

    if(reset) begin
        pc_out <= 0;
        instruction_out <= 0;
    end

    else if(flush) begin
        pc_out <= 0;
        instruction_out <= 0;
    end

    else if(!stall) begin
        pc_out <= pc_in;
        instruction_out <= instruction_in;
    end

end

endmodule