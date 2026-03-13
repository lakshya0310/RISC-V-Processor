module mux2to1 (
    input a, b, sel, 
    output out
);
    wire nsel, temp1, temp2;
    not (nsel, sel);
    and (temp1, a, nsel);
    and (temp2, b, sel);
    or  (out, temp1, temp2);
endmodule

module mux2to1_64(
    input  [63:0] a, b,
    input         sel,
    output [63:0] out
);
    assign out = sel ? b : a;
endmodule
module and_64bit(
    input [63:0] a,
    input [63:0] b,
    output [63:0] z
);
    genvar i;
    generate
        for(i = 0; i < 64; i = i + 1) begin : and_64
            and(z[i], a[i], b[i]);
        end
    endgenerate
endmodule


module or_64bit(
    input [63:0] a, b,
    output [63:0] z
);
    genvar i;
    generate
        for(i = 0; i < 64; i = i + 1) begin : or_64
            or(z[i], a[i], b[i]);
        end
    endgenerate
endmodule

module xor_64bit(
    input [63:0] a, b,
    output [63:0] z
);
    genvar i;
    generate
        for(i = 0; i < 64; i = i + 1) begin : xor_64
            xor(z[i], a[i], b[i]);
        end
    endgenerate
endmodule
module fulladder(
    output sum, 
    output cout, 
    input a, b, cin
);
    wire p, g, t;
    xor (p, a, b);
    xor (sum, p, cin);
    and (g, a, b);
    and (t, p, cin);
    or  (cout, g, t);
endmodule

module adder_subtractor_64bit(
    output [63:0] sum,
    output cout,
    input signed [63:0] a,
    input signed [63:0] b,
    input mode  // 0: addition, 1: subtraction
);
    wire [63:0] b_mode;  // Selected b based on mode
    wire cin;
    wire [64:0] carry;
    
    
    // For subtraction, cin is 1 (to complete the two's complement conversion)
    assign cin = mode;
    assign carry[0] = cin;
    
    genvar i;
    generate
        for(i = 0; i < 64; i = i + 1) begin : fulladder_loop
            xor(b_mode[i], b[i], cin);
            fulladder fa(
                .sum(sum[i]),
                .cout(carry[i+1]),
                .a(a[i]),
                .b(b_mode[i]),
                .cin(carry[i])
            );
        end
    endgenerate
    
    assign cout = carry[64];
endmodule
module slt_sltu_64bit(
    input [63:0] a, b,
    output slt,    // 1 if (signed) a < b
    output sltu    // 1 if (unsigned) a < b
);
    wire [63:0] difference;
    wire cout;
    // Subtract b from a.
    adder_subtractor_64bit sub_inst(
        .a(a),
        .b(b),
        .mode(1'b1), // Always subtraction for comparison
        .sum(difference),
        .cout(cout)
    );
    assign slt  = difference[63]; // Negative difference => a < b (signed)
    assign sltu = ~cout;         // No carry => a < b (unsigned)
endmodule

module sll_64bit (
    input [63:0] A,
    input [5:0] shift,
    output [63:0] Out
);
    wire [63:0] stage0, stage1, stage2, stage3, stage4,stage5;
    genvar i;
    
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage0_loop
            wire in0, in1;
            assign in0 = A[i];
            assign in1 = (i == 0) ? 1'b0 : A[i-1];
            mux2to1 mux0 (.a(in0), .b(in1), .sel(shift[0]), .out(stage0[i]));
        end
    endgenerate
    
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage1_loop
            wire in0, in1;
            assign in0 = stage0[i];
            assign in1 = (i < 2) ? 1'b0 : stage0[i-2];
            mux2to1 mux1 (.a(in0), .b(in1), .sel(shift[1]), .out(stage1[i]));
        end
    endgenerate
    
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage2_loop
            wire in0, in1;
            assign in0 = stage1[i];
            assign in1 = (i < 4) ? 1'b0 : stage1[i-4];
            mux2to1 mux2 (.a(in0), .b(in1), .sel(shift[2]), .out(stage2[i]));
        end
    endgenerate
    
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage3_loop
            wire in0, in1;
            assign in0 = stage2[i];
            assign in1 = (i < 8) ? 1'b0 : stage2[i-8];
            mux2to1 mux3 (.a(in0), .b(in1), .sel(shift[3]), .out(stage3[i]));
        end
    endgenerate

    generate
        for (i = 0; i < 64; i = i + 1) begin : stage4_loop
            wire in0, in1;
            assign in0 = stage3[i];
            assign in1 = (i < 16) ? 1'b0 : stage3[i-16];
            mux2to1 mux4 (.a(in0), .b(in1), .sel(shift[4]), .out(stage4[i]));
        end
    endgenerate
    generate
	    for(i=0;i<64;i=i+1) begin : stage5_loop
		    wire in0,in1;
		    assign in0 = stage4[i];
		    assign in1 = (i<32) ? 1'b0 : stage4[i-32];
		    mux2to1 mux5 (.a(in0) , .b(in1), .sel(shift[5]), .out(stage5[i]));
	    end
    endgenerate
    
    assign Out = stage5;
endmodule

module srl_64bit (
    input [63:0] A,
    input [5:0] shift,
    output [63:0] Out
);
    wire [63:0] stage0, stage1, stage2, stage3, stage4,stage5;
    genvar i;
    
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage0_loop
            wire in0, in1;
            assign in0 = A[i];
            assign in1 = (i < 63) ? A[i+1] : 1'b0;
            mux2to1 mux0 (.a(in0), .b(in1), .sel(shift[0]), .out(stage0[i]));
        end
    endgenerate
    
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage1_loop
            wire in0, in1;
            assign in0 = stage0[i];
            assign in1 = (i < 62) ? stage0[i+2] : 1'b0;
            mux2to1 mux1 (.a(in0), .b(in1), .sel(shift[1]), .out(stage1[i]));
        end
    endgenerate
    
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage2_loop
            wire in0, in1;
            assign in0 = stage1[i];
            assign in1 = (i < 60) ? stage1[i+4] : 1'b0;
            mux2to1 mux2 (.a(in0), .b(in1), .sel(shift[2]), .out(stage2[i]));
        end
    endgenerate
    
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage3_loop
            wire in0, in1;
            assign in0 = stage2[i];
            assign in1 = (i < 56) ? stage2[i+8] : 1'b0;
            mux2to1 mux3 (.a(in0), .b(in1), .sel(shift[3]), .out(stage3[i]));
        end
    endgenerate
    
    // Stage 4: Shift right by 16
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage4_loop
            wire in0, in1;
            assign in0 = stage3[i];
            assign in1 = (i < 48) ? stage3[i+16] : 1'b0;
            mux2to1 mux4 (.a(in0), .b(in1), .sel(shift[4]), .out(stage4[i]));
        end
    endgenerate
    generate
	    for(i=0;i<64;i=i+1) begin : stage5_loop
		    wire in0,in1;
		    assign in0 = stage4[i];
		    assign in1 = (i<32) ? stage4[i+32] : 1'b0;
		    mux2to1 mux5 (.a(in0), .b(in1), .sel(shift[5]), .out(stage5[i]));
	    end
    endgenerate
    
    assign Out = stage5;
endmodule
module sra_64bit (
    input [63:0] A,
    input [5:0] shift,
    output [63:0] Out
);
    wire [63:0] stage0, stage1, stage2, stage3, stage4,stage5;
    genvar i;
    
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage0_loop
            wire in0, in1;
            assign in0 = A[i];
            // For the last bit, use the sign bit (A[63]) instead of 0.
            assign in1 = (i < 63) ? A[i+1] : A[63];
            mux2to1 mux0 (.a(in0), .b(in1), .sel(shift[0]), .out(stage0[i]));
        end
    endgenerate
    
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage1_loop
            wire in0, in1;
            assign in0 = stage0[i];
            assign in1 = (i < 62) ? stage0[i+2] : stage0[63];
            mux2to1 mux1 (.a(in0), .b(in1), .sel(shift[1]), .out(stage1[i]));
        end
    endgenerate
    
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage2_loop
            wire in0, in1;
            assign in0 = stage1[i];
            assign in1 = (i < 60) ? stage1[i+4] : stage1[63];
            mux2to1 mux2 (.a(in0), .b(in1), .sel(shift[2]), .out(stage2[i]));
        end
    endgenerate
    
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage3_loop
            wire in0, in1;
            assign in0 = stage2[i];
            assign in1 = (i < 56) ? stage2[i+8] : stage2[63];
            mux2to1 mux3 (.a(in0), .b(in1), .sel(shift[3]), .out(stage3[i]));
        end
    endgenerate
    
    generate
        for (i = 0; i < 64; i = i + 1) begin : stage4_loop
            wire in0, in1;
            assign in0 = stage3[i];
            assign in1 = (i < 48) ? stage3[i+16] : stage3[63];
            mux2to1 mux4 (.a(in0), .b(in1), .sel(shift[4]), .out(stage4[i]));
        end
    endgenerate
    generate
	    for(i=0; i<64;i=i+1) begin : stage5_loop
		    wire in0,in1;
		    assign in0 = stage4[i];
		    assign in1 = (i<32) ? stage4[i+32] : stage4[63];
		    mux2to1 mux5 (.a(in0), .b(in1), .sel(shift[5]), .out(stage5[i]));
	    end
    endgenerate

    
    assign Out = stage5;
endmodule
module alu_64_bit (
    input  [63:0] a,
    input  [63:0] b,
    input  [3:0]  opcode,
    output reg [63:0] result,
    output        cout,
    output reg    carry_flag,
    output reg    overflow_flag,
    output reg    zero_flag
);

    // Opcode
    localparam  ADD_Oper  = 4'b0000,
                SLL_Oper  = 4'b0001,
                SLT_Oper  = 4'b0010,
                SLTU_Oper = 4'b0011,
                XOR_Oper  = 4'b0100,
                SRL_Oper  = 4'b0101,
                OR_Oper   = 4'b0110,
                AND_Oper  = 4'b0111,
                SUB_Oper  = 4'b1000,
                SRA_Oper  = 4'b1101;

    // Internal wires
    wire [63:0] add_result, sub_result;
    wire [63:0] sll_result, srl_result, sra_result;
    wire [63:0] and_result, or_result, xor_result;
    wire        slt_result, sltu_result;
    wire        add_cout, sub_cout;

    // ADD
    adder_subtractor_64bit add_inst (
        .a(a),
        .b(b),
        .mode(1'b0),
        .sum(add_result),
        .cout(add_cout)
    );

    // SUB
    adder_subtractor_64bit sub_inst (
        .a(a),
        .b(b),
        .mode(1'b1),
        .sum(sub_result),
        .cout(sub_cout)
    );

    // Logic
    and_64bit and_inst (.a(a), .b(b), .z(and_result));
    or_64bit  or_inst  (.a(a), .b(b), .z(or_result));
    xor_64bit xor_inst (.a(a), .b(b), .z(xor_result));

    // Shifts
    sll_64bit sll_inst (.A(a), .shift(b[5:0]), .Out(sll_result));
    srl_64bit srl_inst (.A(a), .shift(b[5:0]), .Out(srl_result));
    sra_64bit sra_inst (.A(a), .shift(b[5:0]), .Out(sra_result));

    // SLT / SLTU
    slt_sltu_64bit slt_inst (
        .a(a),
        .b(b),
        .slt(slt_result),
        .sltu(sltu_result)
    );

    // ALU result selection
    always @(*) begin
        carry_flag    = 1'b0;
        overflow_flag = 1'b0;

        case (opcode)
            ADD_Oper: begin
                result = add_result;
                carry_flag = add_cout;
                overflow_flag = (~(a[63] ^ b[63])) & (a[63] ^ result[63]);
            end

            SUB_Oper: begin
                result = sub_result;
                carry_flag = sub_cout;
                overflow_flag = ((a[63] ^ b[63])) & (a[63] ^ result[63]);
            end

            AND_Oper: result = and_result;
            OR_Oper:  result = or_result;
            XOR_Oper: result = xor_result;

            SLL_Oper: result = sll_result;
            SRL_Oper: result = srl_result;
            SRA_Oper: result = sra_result;

            SLT_Oper:  result = {{63{1'b0}}, slt_result};
            SLTU_Oper: result = {{63{1'b0}}, sltu_result};

            default: result = 64'b0;
        endcase
    end

    // Flags
    assign cout = carry_flag;

    always @(*) begin
        zero_flag = (result == 64'b0);
    end

endmodule
