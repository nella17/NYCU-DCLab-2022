`define ROL32(x, c) (((x) << (c)) | ((x) >> (32 - (c))))

`timescale 1ns / 1ps
module md5 (
    input  clk,
    input  reset_n,
    input  [0:8*8-1] in_msg,
    input  in_start,
    output out_done,
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

    localparam [0:2] S_IDLE = 0,
                     S_CALC = 1,
                     S_INCR = 2,
                     S_OUTP = 3,
                     S_DONE = 4;
    reg [0:2] P = S_IDLE, P_next;

    reg [5:0] i, i1;

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

    reg [0:512-1] msg = 0;
    wire [0:31] w [0:15];
    generate for(gi = 0; gi < 16; gi = gi+1) begin
        assign w[gi] = trans_endian( msg[gi*32 +: 32] );
    end endgenerate

    assign out_done = P == S_DONE;
    always @(posedge clk) begin
        if (~reset_n)
            P <= S_IDLE;
        else
            P <= P_next;
    end
    always @(*) begin
        case (P)
        S_IDLE:
            if (in_start)
                P_next = S_CALC;
            else
                P_next = S_IDLE;
        S_CALC:
            P_next = S_INCR;
        S_INCR:
            if (i == 64 - 1)
                P_next = S_OUTP;
            else
                P_next = S_INCR;
        S_OUTP:
            P_next = S_DONE;
        S_DONE:
            P_next = S_IDLE;
        default:
            P_next = S_IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (~reset_n)
            msg <= 0;
        else if (P == S_IDLE && in_start) begin
            msg[0 +: 64] <= in_msg;
            msg[64 +: 8] <= 8'd128;
            msg[56*8 +: 8] <= 8'd64;
        end
    end

    always @(posedge clk) begin
        if (~reset_n || P == S_IDLE) begin
            i <= 0;
            i1 <= 1;
        end else if (P == S_INCR) begin
            i <= i + 1;
            i1 <= i1 + 1;
        end
    end

    reg [0:31] a, b, c, d, t;
    wire [0:31] f;
    assign f = F(i, b, c, d);
    reg [0:4*64-1] g_table = {
        4'h0, 4'h1, 4'h2, 4'h3, 4'h4, 4'h5, 4'h6, 4'h7, 4'h8, 4'h9, 4'ha, 4'hb, 4'hc, 4'hd, 4'he, 4'hf,
        4'h1, 4'h6, 4'hb, 4'h0, 4'h5, 4'ha, 4'hf, 4'h4, 4'h9, 4'he, 4'h3, 4'h8, 4'hd, 4'h2, 4'h7, 4'hc,
        4'h5, 4'h8, 4'hb, 4'he, 4'h1, 4'h4, 4'h7, 4'ha, 4'hd, 4'h0, 4'h3, 4'h6, 4'h9, 4'hc, 4'hf, 4'h2,
        4'h0, 4'h7, 4'he, 4'h5, 4'hc, 4'h3, 4'ha, 4'h1, 4'h8, 4'hf, 4'h6, 4'hd, 4'h4, 4'hb, 4'h2, 4'h9
    };
    wire [0:3] g1 = g_table[i1*4 +: 4];

    assign out_hash = {
        trans_endian(a),
        trans_endian(b),
        trans_endian(c),
        trans_endian(d)
    };
    always @(posedge clk) begin
        if (~reset_n || P == S_IDLE) begin
            a <= h[0]; b <= h[1]; c <= h[2]; d <= h[3];
        end else if (P == S_CALC) begin
            t <= a + k[i] + w[0];
        end else if (P == S_INCR) begin
            a <= d;
            b <= b + `ROL32(f + t, r[i]);
            c <= b;
            d <= c;
            t <= d + k[i1] + w[g1];
        end else if (P == S_OUTP) begin
            a <= a + h[0];
            b <= b + h[1];
            c <= c + h[2];
            d <= d + h[3];
        end
    end

endmodule
