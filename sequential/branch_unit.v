module branch_unit (

    input Branch,
    input zero_flag,

    output PCSrc

);

assign PCSrc = Branch & zero_flag;

endmodule