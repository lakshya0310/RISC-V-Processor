module alusrc_mux(
    input wire ALUSrc,
    input wire [63:0] forwardB_data,
    input wire [63:0] immediate,
    output wire [63:0] alu_input2
);

assign alu_input2 = (ALUSrc) ? immediate : forwardB_data;

endmodule