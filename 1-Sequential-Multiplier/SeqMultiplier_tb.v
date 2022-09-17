`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/17/2022 02:23:50 PM
// Design Name: 
// Module Name: SeqMultiplier_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module SeqMultiplier_tb();
    reg clk = 1;
    reg enable;
    reg [7:0] A, B;
    wire [15:0] C;
    
    SeqMultiplier uut(.clk(clk), .enable(enable), .A(A), .B(B), .C(C));
    
    always #5 clk = !clk;
    
    initial begin
        A = 0; B = 0; enable = 0;
        #100;
        
        enable = 0;
        A = 8'b01010101; B = 8'b00011000;
        #20;
        enable = 1;
        #80;

        enable = 0;
        A = 8'b10011001; B = 8'b1000001;
        #20;
        enable = 1;
        #80;
    end
endmodule
