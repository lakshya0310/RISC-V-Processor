`timescale 1ns / 1ps

module if_stage_tb;
    // Testbench Signals
    reg clk;
    reg reset;
    reg Branch;
    reg Zero;
    reg [63:0] imm;
    
    wire [31:0] instr;
    wire [63:0] pc_out;

    // Instantiate the Fetch Stage Wrapper
    Instruction_Fetch_Stage uut (
        .clk(clk),
        .reset(reset),
        .Branch(Branch),
        .Zero(Zero),
        .imm(imm),
        .instr(instr),
        .pc_out(pc_out)
    );

    // Clock generation: 10ns period (100MHz)
    always #5 clk = ~clk;

    initial begin

        $dumpfile("if_stage.vcd");
        $dumpvars(0, if_stage_tb);
        
        // --- Initialization ---
        clk = 0;
        reset = 1;
        Branch = 0;
        Zero = 0;
        imm = 64'd0;

        // Reset the system
        #15 reset = 0;
        $display("Time\t PC_Out\t\t Instruction");
        $display("------------------------------------------");

        // --- Test 1: Sequential Execution (PC + 4) ---
        // Let it run for 3 cycles to see PC go 0 -> 4 -> 8
        repeat (3) @(posedge clk);
        $display("%t\t %h\t %h", $time, pc_out, instr);

        // --- Test 2: Successful Branch (PC + Imm) ---
        // Simulate a BEQ where registers are equal (Zero=1)
        // Let's say we want to jump 16 bytes forward
        imm = 64'd16; 
        Branch = 1;
        Zero = 1;
        
        @(posedge clk);
        #1; // Wait for logic to settle
        $display("%t\t %h\t %h (Branched!)", $time, pc_out, instr);

        // --- Test 3: Failed Branch (Stay at PC + 4) ---
        // Branch is 1 but Zero is 0 (Condition not met)
        Branch = 1;
        Zero = 0;
        
        @(posedge clk);
        #1;
        $display("%t\t %h\t %h (Branch Failed - Sequential)", $time, pc_out, instr);

        #20;
        $finish;
    end

    // Monitor for debugging
    initial begin
        $monitor("Cycle: PC=%h, Instr=%h, Branch=%b, Zero=%b", pc_out, instr, Branch, Zero);
    end

endmodule