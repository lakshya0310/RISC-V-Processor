`timescale 1ns/1ps
`define IMEM_SIZE 4096
`define DMEM_SIZE 1024
`define MAX_CYCLES 2000

`include "cpu_top.v"

module seq_tb;

reg clk;
reg reset;

integer cycles;
reg stop_flag;

integer file_reg;
integer i;

cpu_top_pipelined uut(
    .clk(clk),
    .reset(reset)
);

////////////////////////////////////////////////////////////
//////////////////// CLOCK GENERATION //////////////////////
////////////////////////////////////////////////////////////

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

////////////////////////////////////////////////////////////
//////////////////// SIMULATION ////////////////////////////
////////////////////////////////////////////////////////////

initial begin

    $dumpfile("cpu_pipelined.vcd");
    $dumpvars(0, seq_tb);

    reset = 1;
    cycles = 0;
    stop_flag = 0;

    #20;
    reset = 0;

    $display("\n================ PIPELINED CPU TRACE ================\n");

    while(!stop_flag && cycles < `MAX_CYCLES) begin

        @(posedge clk);
        cycles = cycles + 1;

        ////////////////////////////////////////////////////////////
        // STOP CONDITIONS
        ////////////////////////////////////////////////////////////

        // PC became invalid
        if(^uut.pc === 1'bx) begin
            $display("\n*** PC became X at %0t. Stopping. ***\n",$time);
            stop_flag = 1;
        end

        // instruction became invalid (memory out of range)
        else if(^uut.instruction === 1'bx) begin
            $display("\n*** Invalid instruction fetched. Program finished. ***\n");
            stop_flag = 1;
        end

        // ECALL instruction
        else if(uut.instruction == 32'h00100073) begin
            $display("\n*** ECALL detected ***\n");
            stop_flag = 1;
        end

        ////////////////////////////////////////////////////////////
        // PIPELINE TRACE
        ////////////////////////////////////////////////////////////

        $display("--------------------------------------------------");
        $display("Cycle: %0d   Time: %0t ns",cycles,$time);

        $display("PC = %016x",uut.pc);
        $display("Instruction = %08x",uut.instruction);

        $display("opcode=%07b rd=x%0d rs1=x%0d rs2=x%0d",
            uut.instruction[6:0],
            uut.instruction[11:7],
            uut.instruction[19:15],
            uut.instruction[24:20]
        );

        $display("\nPipeline State:");
        $display("IF  : %08x", uut.instruction);
        $display("ID  : %08x", uut.IF_ID_instruction);
        $display("EX  : %08x", uut.ID_EX_instruction);

        $display("\nEX Stage:");
        $display("ALU Result = %016x", uut.alu_result);

        $display("\nBranch Taken = %b", uut.branch_taken);
        $display("Branch Target = %016x", uut.branch_target);

        $display("\nControl Signals:");
        $display("EX_MemRead=%b EX_MemWrite=%b EX_RegWrite=%b",
                uut.EX_MemRead, uut.EX_MemWrite, uut.EX_RegWrite);

        $display("\nWriteback Stage:");
        $display("MEM_WB_MemtoReg=%b MEM_WB_RegWrite=%b MEM_WB_rd=x%0d",
            uut.MEM_WB_MemtoReg,
            uut.MEM_WB_RegWrite,
            uut.MEM_WB_rd
        );

        if(uut.MEM_WB_RegWrite && uut.MEM_WB_rd != 0)
            $display(">>> WRITEBACK: x%0d <= %016x",
                uut.MEM_WB_rd,
                uut.write_back_data
            );

        if(uut.EX_MEM_MemWrite)
            $display(">>> STORE: Addr=%016x Data=%016x",
                uut.EX_MEM_alu_result,
                uut.EX_MEM_write_data
            );

        if(uut.EX_MEM_MemRead)
            $display(">>> LOAD request: Addr=%016x",
                uut.EX_MEM_alu_result
            );

        $display("\nRegister Snapshot:");
        $display("x1=%016x x2=%016x x3=%016x x4=%016x x5=%016x",
            uut.RF.regs[1],
            uut.RF.regs[2],
            uut.RF.regs[3],
            uut.RF.regs[4],
            uut.RF.regs[5]
        );

    end

    ////////////////////////////////////////////////////////////
    // PIPELINE DRAIN
    ////////////////////////////////////////////////////////////

    $display("\nExecution finished after %0d cycles\n",cycles);

    repeat(5) @(posedge clk);

    ////////////////////////////////////////////////////////////
    // WRITE REGISTER FILE
    ////////////////////////////////////////////////////////////

    file_reg = $fopen("register_file.txt","w");

    for(i=0;i<32;i=i+1)
        $fdisplay(file_reg,"%016x",uut.RF.regs[i]);

    $fdisplay(file_reg,"%0d",cycles);

    $fclose(file_reg);

    #10;
    $finish;

end

endmodule
