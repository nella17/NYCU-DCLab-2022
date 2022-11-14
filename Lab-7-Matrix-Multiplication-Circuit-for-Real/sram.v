`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2018/11/01 11:27:19
// Design Name: 
// Module Name: sram
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// This module show you how to infer an initialized SRAM block
// in your circuit using the standard Verilog code.  The initial
// values of the SRAM cells is defined in the text file "matrices.mem"
// Each line defines a cell value. The number of data in matrices.mem
// must match the size of the sram block exactly. Therefore, we have to
// add zero paddings to the data.
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sram #(
    parameter DATA_WIDTH = 8, ADDR_WIDTH = 11, RAM_SIZE = 1024
)(
    input clk,
    input we,
    input en,
    input  [0: ADDR_WIDTH-1] addr,
    input  [0: DATA_WIDTH-1] data_i,
    output reg [0: DATA_WIDTH-1] data_o
);

    wire write = en & we;

    // Declareation of the memory cells
    reg [0: DATA_WIDTH-1] RAM [0: RAM_SIZE-1];

    // ------------------------------------
    // SRAM cell initialization
    // ------------------------------------
    // Initialize the sram cells with the values defined in "matrices.mem"
    initial begin
        $readmemh("matrices.mem", RAM);
    end

    // ------------------------------------
    // SRAM read operation
    // ------------------------------------
    always@(posedge clk) begin
        date_o <=  write ? data_i : RAM[addr];
    end

    // ------------------------------------
    // SRAM write operation
    // ------------------------------------
    always@(posedge clk) begin
        if (write) RAM[addr] <= data_i;
    end

endmodule
