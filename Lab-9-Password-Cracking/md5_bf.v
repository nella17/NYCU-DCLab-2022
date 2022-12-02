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

    localparam [0:1] S_IDLE = 0,
                     S_CALC = 1,
                     S_DONE = 2;
    reg [0:1] P = S_IDLE, P_next;

    reg [31:0] number, in_pass;
    wire [0:7] _add;
    wire ndec;

    reg [8*8-1:0] md5_in;
    wire md5_start = ndec;
    wire md5_done;
    wire [31:0] md5_pass;
    wire [127:0] md5_out;

    md5 md5(
        .clk(clk),
        .reset_n(reset_n),
        .in_msg(md5_in),
        .in_pass(in_pass),
        .in_start(md5_start),
        .out_done(md5_done),
        .out_pass(md5_pass),
        .out_hash(md5_out)
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
                P_next = S_CALC;
            else
                P_next = S_IDLE;
        S_CALC:
            if (found || md5_pass == high)
                P_next = S_DONE;
            else
                P_next = S_CALC;
        S_DONE:
            P_next = S_DONE;
        default:
            P_next = S_IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (md5_done && md5_out === hash) begin
            found <= 1;
            pass <= md5_pass;
        end else if (~reset_n || P == S_IDLE || ~found) begin
            found <= 0;
            pass <= 0;
        end
    end

    wire [31:0] add = ndec +
                    + (_add[0] ? 31'h00000006 : 0)
                    + (_add[1] ? 31'h00000060 : 0)
                    + (_add[2] ? 31'h00000600 : 0)
                    + (_add[3] ? 31'h00006000 : 0)
                    + (_add[4] ? 31'h00060000 : 0)
                    + (_add[5] ? 31'h00600000 : 0)
                    + (_add[6] ? 31'h06000000 : 0)
                    + (_add[7] ? 31'h06000000 : 0);
    always @(posedge clk) begin
        if (~reset_n || P == S_IDLE)
            number <= low;
        else
            number <= number + add;
    end

    assign ndec = 1;
    generate for(gi = 0; gi < 8; gi = gi+1) begin
        assign _add[gi] = (gi ? _add[gi-1] : 1) && number[gi*4 +: 4] == 9;
    end endgenerate

    reg [3:0] i;
    always @(posedge clk) begin
        in_pass <= number;
        `N2T(i, 8, number, 0, md5_in, 0)
    end

endmodule
