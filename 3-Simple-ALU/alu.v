`define PSA 3'b000
`define ADD 3'b001
`define SUB 3'b010
`define AND 3'b011
`define XOR 3'b100
`define ABS 3'b101
`define MUL 3'b110
`define PSD 3'b111

module alu(
    input signed [7:0] data,
    input signed [7:0] accum,
    input [2:0] opcode,
    input clk,
    input reset,
    output reg [7:0] alu_out,
    output zero
);

    wire signed [3:0] Ldata = data[3:0];
    wire signed [3:0] Laccum = accum[3:0];

    assign zero = ~|accum;
    
    always @(posedge clk) begin
        if (reset) begin
            alu_out <= 0;
        end
        else begin
            casez (opcode)
                `PSA : alu_out <= accum;
                `ADD : alu_out <= accum + data;
                `SUB : alu_out <= accum - data;
                `AND : alu_out <= accum & data;
                `XOR : alu_out <= accum ^ data;
                `ABS : alu_out <= accum < 0 ? -accum : accum;
                `MUL : alu_out <= Laccum * Ldata;
                `PSD : alu_out <= data;
                default: alu_out <= 0;
            endcase
        end
    end

endmodule
