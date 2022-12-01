`define ROL32(x, c) (((x) << (c)) | ((x) >> (32 - (c))))

`timescale 1ns / 1ps
module md5 (
    input  clk,
    input  reset_n,
    input  [0:8*8-1] in_msg,
    input  in_start,
    input  [31:0] in_pass,
    output reg out_done,
    output reg [31:0] out_pass,
    output [0:8*16-1] out_hash
);
    function [0:31] trans_endian (input [0:31] in); begin
        trans_endian = {
            in[24:31],
            in[16:23],
            in[ 8:15],
            in[ 0: 7]
        };
    end endfunction

    function [0:31] F (input [5:0] i, input [0:31] b, input [0:31] c, input [0:31] d); begin
        case (i[5:4])
            0: F = ((b & c) | ((~b) & d));
            1: F = ((d & b) | ((~d) & c));
            2: F = (b ^ c ^ d);
            3: F = (c ^ (b | (~d)));
        endcase
    end endfunction

    genvar gi, gp;

    reg [0:32*64-1] k_raw = {
        32'hd76aa478, 32'he8c7b756, 32'h242070db, 32'hc1bdceee,
        32'hf57c0faf, 32'h4787c62a, 32'ha8304613, 32'hfd469501,
        32'h698098d8, 32'h8b44f7af, 32'hffff5bb1, 32'h895cd7be,
        32'h6b901122, 32'hfd987193, 32'ha679438e, 32'h49b40821,
        32'hf61e2562, 32'hc040b340, 32'h265e5a51, 32'he9b6c7aa,
        32'hd62f105d, 32'h02441453, 32'hd8a1e681, 32'he7d3fbc8,
        32'h21e1cde6, 32'hc33707d6, 32'hf4d50d87, 32'h455a14ed,
        32'ha9e3e905, 32'hfcefa3f8, 32'h676f02d9, 32'h8d2a4c8a,
        32'hfffa3942, 32'h8771f681, 32'h6d9d6122, 32'hfde5380c,
        32'ha4beea44, 32'h4bdecfa9, 32'hf6bb4b60, 32'hbebfbc70,
        32'h289b7ec6, 32'heaa127fa, 32'hd4ef3085, 32'h04881d05,
        32'hd9d4d039, 32'he6db99e5, 32'h1fa27cf8, 32'hc4ac5665,
        32'hf4292244, 32'h432aff97, 32'hab9423a7, 32'hfc93a039,
        32'h655b59c3, 32'h8f0ccc92, 32'hffeff47d, 32'h85845dd1,
        32'h6fa87e4f, 32'hfe2ce6e0, 32'ha3014314, 32'h4e0811a1,
        32'hf7537e82, 32'hbd3af235, 32'h2ad7d2bb, 32'heb86d391
    };
    wire [0:31] k [0:63];
    generate for(gi = 0; gi < 64; gi = gi+1) begin
        assign k[gi] = k_raw[gi * 32 +: 32];
    end endgenerate

    reg [0:32*4-1] h_raw = {
        32'h67452301,
        32'hefcdab89,
        32'h98badcfe,
        32'h10325476
    };
    wire [0:31] h [0:3];
    generate for(gi = 0; gi < 4; gi = gi+1) begin
        assign h[gi] = h_raw[gi * 32 +: 32];
    end endgenerate

    reg [0:5*64-1] r_raw = {
        5'd07, 5'd12, 5'd17, 5'd22, 5'd07, 5'd12, 5'd17, 5'd22, 5'd07, 5'd12, 5'd17, 5'd22, 5'd07, 5'd12, 5'd17, 5'd22,
        5'd05, 5'd09, 5'd14, 5'd20, 5'd05, 5'd09, 5'd14, 5'd20, 5'd05, 5'd09, 5'd14, 5'd20, 5'd05, 5'd09, 5'd14, 5'd20,
        5'd04, 5'd11, 5'd16, 5'd23, 5'd04, 5'd11, 5'd16, 5'd23, 5'd04, 5'd11, 5'd16, 5'd23, 5'd04, 5'd11, 5'd16, 5'd23,
        5'd06, 5'd10, 5'd15, 5'd21, 5'd06, 5'd10, 5'd15, 5'd21, 5'd06, 5'd10, 5'd15, 5'd21, 5'd06, 5'd10, 5'd15, 5'd21
    };
    wire [0:4] r [0:63];
    generate for(gi = 0; gi < 64; gi = gi+1) begin
        assign r[gi] = r_raw[gi * 5 +: 5];
    end endgenerate

    reg [0:4*64-1] g_table = {
        4'h0, 4'h1, 4'h2, 4'h3, 4'h4, 4'h5, 4'h6, 4'h7, 4'h8, 4'h9, 4'ha, 4'hb, 4'hc, 4'hd, 4'he, 4'hf,
        4'h1, 4'h6, 4'hb, 4'h0, 4'h5, 4'ha, 4'hf, 4'h4, 4'h9, 4'he, 4'h3, 4'h8, 4'hd, 4'h2, 4'h7, 4'hc,
        4'h5, 4'h8, 4'hb, 4'he, 4'h1, 4'h4, 4'h7, 4'ha, 4'hd, 4'h0, 4'h3, 4'h6, 4'h9, 4'hc, 4'hf, 4'h2,
        4'h0, 4'h7, 4'he, 4'h5, 4'hc, 4'h3, 4'ha, 4'h1, 4'h8, 4'hf, 4'h6, 4'hd, 4'h4, 4'hb, 4'h2, 4'h9
    };

    reg [0:512-1] msg [0:64];
    wire [0:31] w [0:63] [0:15];
    generate for(gp = 0; gp < 64; gp = gp+1) begin
        for(gi = 0; gi < 16; gi = gi+1) begin
            assign w[gp][gi] = trans_endian( msg[gp][gi*32 +: 32] );
        end
    end endgenerate

    reg [64:0] valid;
    reg [31:0] pass [0:64], pass_delay;
    reg done_delay;

    always @(posedge clk) begin
        if (~reset_n) begin
            msg[0] <= 0;
            pass[0] <= 0;
        end else begin
            msg[0] <= { in_msg, 8'd128, 376'd0, 8'd64, 56'd0 };
            pass[0] <= in_pass;
        end
    end

    always @(posedge clk) begin
        if (~reset_n) begin
            { out_done, done_delay, valid } <= 0;
            pass_delay <= 0;
            out_pass <= 0;
        end else begin
            { out_done, done_delay, valid } <= { done_delay, valid, in_start };
            pass_delay <= pass[64];
            out_pass <= pass_delay;
        end
    end

    generate for(gp = 0; gp < 64; gp = gp+1) begin
        always @(posedge clk) begin
            if (~reset_n) begin
                msg[gp+1] <= 0;
                pass[gp+1] <= 0;
            end else begin
                msg[gp+1] <= msg[gp];
                pass[gp+1] <= pass[gp];
            end
        end
    end endgenerate

    reg [0:31] a [0:64], b [0:64], c [0:64], d [0:64], t [0:64];
    wire [0:31] f [0:63];
    wire [0:3] g [0:63];
    generate for(gp = 0; gp < 64; gp = gp+1) begin
        assign f[gp] = F(gp, b[gp], c[gp], d[gp]);
        assign g[gp] = g_table[gp*4 +: 4];
    end endgenerate

    assign out_hash = {
        trans_endian(a[64] + h[0]),
        trans_endian(b[64] + h[1]),
        trans_endian(c[64] + h[2]),
        trans_endian(d[64] + h[3])
    };

    always @(posedge clk) begin
        a[0] <= h[0];
        b[0] <= h[1];
        c[0] <= h[2];
        d[0] <= h[3];
        t[0] <= h[0] + k[0] + w[0][0];
    end

    generate for(gp = 1; gp <= 64; gp = gp+1) begin
        always @(posedge clk) begin
            a[gp] <= d[gp-1];
            b[gp] <= b[gp-1] + `ROL32(f[gp-1] + t[gp-1], r[gp-1]);
            c[gp] <= b[gp-1];
            d[gp] <= c[gp-1];
            t[gp] <= d[gp-1] + k[gp] + w[gp][g[gp]];
        end
    end endgenerate

endmodule
