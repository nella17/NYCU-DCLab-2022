`define N2T(i, bits, in, of, out, off) \
    for(i = 0; i < bits; i = i+1) \
        out[8*(off+i) +: 8] <= in[(i+of)*4 +: 4] + ((in[(i+of)*4 +: 4] < 10) ? "0" : "A"-10);

`timescale 1ns / 1ps
module md5_bf (
    input  clk,
    input  reset_n,
    input  start,
    input  [31:0] low,
    input  [31:0] high,
    input [127:0] hash,
    output done,
    output reg found,
    output reg [31:0] pass
);
    genvar gi;

    localparam [0:2] S_IDLE = 0,
                     S_INIT = 1,
                     S_VALD = 2,
                     S_CALC = 3,
                     S_CHEK = 4,
                     S_INCR = 5,
                     S_DONE = 6;
    reg [0:2] P = S_IDLE, P_next;

    reg [31:0] number;
    wire [0:7] _ndec;
    wire ndec;

    reg [8*8-1:0] md5_in = "53589793";
    wire md5_start = P == S_CALC;
    wire md5_done;
    wire [127:0] md5_out;

    md5 md5(
        .clk(clk),
        .reset_n(reset_n),
        .in(md5_in),
        .start(md5_start),
        .done(md5_done),
        .out(md5_out)
    );

    assign done = P == S_DONE;
    always @(posedge clk) begin
        if (~reset_n)
            P <= S_IDLE;
        else
            P <= P_next;
    end
    always @(*) begin
        case (P)
        S_IDLE:
            if (start)
                P_next = S_INIT;
            else
                P_next = S_IDLE;
        S_INIT:
            P_next = S_VALD;
        S_VALD:
            if (ndec)
                P_next = S_CALC;
            else
                P_next = S_INCR;
        S_CALC:
            if (md5_done)
                P_next = S_CHEK;
            else
                P_next = S_CALC;
        S_CHEK:
            if (found || number == high)
                P_next = S_DONE;
            else
                P_next = S_INCR;
        S_INCR:
            P_next = S_INIT;
        S_DONE:
            P_next = S_DONE;
        default:
            P_next = S_IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (md5_done && md5_out === hash) begin
            found <= 1;
            pass <= number;
        end else begin
            found <= 0;
            pass <= 0;
        end
    end

    always @(posedge clk) begin
        if (~reset_n || P == S_IDLE) begin
            number <= low;
        end else if (P == S_INCR) begin
            number <= number + (number != high);
        end
    end

    assign ndec = &(_ndec);
    generate for(gi = 0; gi < 8; gi = gi+1) begin
        assign _ndec[gi] = (0 <= number[gi*4 +: 4] && number[gi*4 +: 4] <= 9);
    end endgenerate

    reg [3:0] i;
    always @(posedge clk) begin
        if (P == S_INIT)
            `N2T(i, 8, number, 0, md5_in, 0)
    end

endmodule
