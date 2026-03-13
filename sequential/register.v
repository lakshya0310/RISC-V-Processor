module register_file(
    input  wire        clk,
    input  wire        reset,

    input  wire [4:0]  read_reg1,
    input  wire [4:0]  read_reg2,
    input  wire [4:0]  write_reg,

    input  wire [63:0] write_data,
    input  wire        regwrite,

    output wire [63:0] read_data1,
    output wire [63:0] read_data2
);

    reg [63:0] regs [31:0];
    integer i;

    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 64'b0;
        end else if (regwrite && write_reg != 5'd0) begin
            regs[write_reg] <= write_data;
        end
    end

    assign read_data1 = (read_reg1 == 5'd0) ? 64'b0 : regs[read_reg1];
    assign read_data2 = (read_reg2 == 5'd0) ? 64'b0 : regs[read_reg2];

endmodule
