/*
* Module describing a 32-bit ripple carry adder, with no carry output or input
*/
module adder32 import calculator_pkg::*; (
    input logic [DATA_W - 1 : 0] a_i,
    input logic [DATA_W - 1 : 0] b_i,
    output logic [DATA_W - 1 : 0] sum_o
);
    logic [32:0] carry;
    assign carry[0] = 0;
    genvar i;
    //Use a generate block to chain together 32 full adders. 
    //Imagine you are connecting 32 single-bit adder modules together. 
    generate
        for (i = 0; i < 32; i = i + 1) begin
            assign sum_o[i] = (a_i[i]^b_i[i])^carry[i];
            assign carry[i+1] = (a_i[i]&b_i[i]) | ((a_i[i]^b_i[i])&carry[i]);
        end
    endgenerate
endmodule