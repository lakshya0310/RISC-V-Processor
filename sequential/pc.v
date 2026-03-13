module PC(
    input clk,
    input reset,
    input [63:0] pc_in,
    output reg [63:0] pc_out
);
    always @(posedge clk or posedge reset) begin
        if(reset)
            pc_out <= 64'd0; 
        else
            pc_out <= pc_in; 
    end
endmodule

module PC_adder(
    input [63:0] pc,
    output [63:0] pc_4
);
    assign pc_4 = pc + 64'd4; 
endmodule

module PC_branchadder(
    input [63:0] pc_curr,
    input [63:0] imm,
    output [63:0] branch_target
);
    assign branch_target = pc_curr + imm; 
endmodule

module next_pc_mux(
    input Branch,
    input Zero,
    input [63:0] pc_plus4,
    input [63:0] branch_target,
    output reg [63:0] next_pc
);
    always @(*) begin
       
        if (Branch && Zero)
            next_pc = branch_target;
        else
            next_pc = pc_plus4;
    end
endmodule