`timescale 1ns/1ps

module pc_tb;

reg clk;
reg reset;
reg Branch;
reg Zero;
reg [63:0] imm;

wire [63:0] pc_out;
wire [63:0] pc_plus4;
wire [63:0] branch_target;
wire [63:0] next_pc;

// ---------- Instantiate Modules ----------

PC pc_inst(
    .clk(clk),
    .reset(reset),
    .pc_in(next_pc),
    .pc_out(pc_out)
);

PC_adder adder_inst(
    .pc(pc_out),
    .pc_4(pc_plus4)
);

PC_branchadder branchadder_inst(
    .pc_curr(pc_out),
    .imm(imm),
    .branch_target(branch_target)
);

next_pc_mux mux_inst(
    .Branch(Branch),
    .Zero(Zero),
    .pc_plus4(pc_plus4),
    .branch_target(branch_target),
    .next_pc(next_pc)
);

// ---------- Clock ----------
always #5 clk = ~clk;   // 10ns period

// ---------- Stimulus ----------
initial begin

    $dumpfile("pc.vcd");
    $dumpvars(0, pc_tb);

    clk = 0;
    reset = 1;
    Branch = 0;
    Zero = 0;
    imm = 64'd16;

    #10 reset = 0;      // release reset

    // Normal increment
    #20;

    // Branch NOT taken
    Branch = 1;
    Zero = 0;
    #20;

    // Branch taken
    Branch = 1;
    Zero = 1;
    #20;

    // Back to normal
    Branch = 0;
    Zero = 0;
    #20;

    $finish;
end

endmodule