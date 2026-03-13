module branch_flush(

input branch_taken,

output flush_IF_ID,
output flush_ID_EX

);

assign flush_IF_ID = branch_taken;
assign flush_ID_EX = 1'b0;

endmodule
