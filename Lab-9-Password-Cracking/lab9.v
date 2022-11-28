`define STRCPY(i, size, in, of, out, off) \
    for(i = 0; i < size; i = i+1) \
        out[off+i] <= in[(i+of)*8 +: 8];
`define N2T(i, bits, in, of, out, off) \
    for(i = 0; i < bits; i = i+1) \
        out[8*(off+i) +: 8] <= in[(i+of)*4 +: 4] + ((in[(i+of)*4 +: 4] < 10) ? "0" : "A"-10);

`timescale 1ns / 1ps
module lab9 (
    input clk,
    input reset_n,
    input [3:0] usr_btn,
    output LCD_RS,
    output LCD_RW,
    output LCD_E,
    output [3:0] LCD_D
);
    localparam CRLF = "\x0D\x0A";
    genvar gi;

    reg [127:0] passwd_hash = 128'h29bdfd85ffb9655b0c34d4b85d7c8bc6; // 00004231

    localparam [0:1] S_IDLE = 0,
                     S_CALC = 1,
                     S_SHOW = 2,
                     S_DONE = 3;
    reg [0:1] P = S_IDLE, P_next;
    reg [31:0] pass;
    reg found;

    localparam row_B_hash = "????????????????";
    localparam row_A_idle = "Hit BTN3 to run ";
    localparam row_A_sear = "Search md5(PASS)";
    localparam row_A_done = "Passwd: xxxxxxxx";
    localparam row_B_done = "Time: yyyyyyy ms";

    reg [127:0] row_A = row_A_idle;
    reg [127:0] row_B = row_B_hash;
    wire [255+8*4:0] row = { row_A, CRLF, row_B, CRLF };

    wire [3:0] btn, btn_pressed;
    reg  [3:0] prev_btn;

    generate for(gi = 0; gi < 4; gi = gi+1) begin
        debounce db_btn(.clk(clk), .reset_n(reset_n), .in(usr_btn[gi]), .out(btn[gi]));
    end endgenerate

    LCD_module lcd0( 
        .clk(clk),
        .reset(~reset_n),
        .row_A(row_A),
        .row_B(row_B),
        .LCD_E(LCD_E),
        .LCD_RS(LCD_RS),
        .LCD_RW(LCD_RW),
        .LCD_D(LCD_D)
    );

    wire md5_start = P == S_CALC;
    reg [31:0] md5_low = 0, md5_high = 32'h99999999;
    wire md5_done, md5_found;
    wire [31:0] md5_pass;

    md5_bf md5_bf(
        .clk(clk),
        .reset_n(reset_n),
        .start(md5_start),
        .low(md5_low),
        .high(md5_high),
        .hash(passwd_hash),
        .done(md5_done),
        .found(md5_found),
        .pass(md5_pass)
    );

    always @(posedge clk) begin
        if (~reset_n)
            P <= S_IDLE;
        else
            P <= P_next;
    end
    always @(*) begin
        case (P)
        S_IDLE:
            if (btn_pressed[3])
                P_next = S_CALC;
            else
                P_next = S_IDLE;
        S_CALC:
            if (found)
                P_next = S_SHOW;
            else
                P_next = S_CALC;
        S_SHOW:
            P_next = S_DONE;
        S_DONE:
            P_next = S_DONE;
        default:
            P_next = S_IDLE;
        endcase
    end

    always @(posedge clk) begin
        prev_btn <= ~reset_n ? 0 : btn;
    end
    assign btn_pressed = ~prev_btn & btn;

    always @(posedge clk) begin
        if (~reset_n)
            found <= 0;
        else if (md5_found) begin
            found <= 1;
            pass <= md5_pass;
        end
    end

    reg [7:0] i;
    always @(posedge clk) begin
        if (~reset_n)
            { row_A, row_B } <= { row_A_idle, row_B_hash };
        else if (P == S_IDLE || P == S_CALC)
            `N2T(i, 16, passwd_hash, 16, row_B, 0)
        else if (P == S_SHOW)
            { row_A, row_B } <= { row_A_done, row_B_done };
        else if (P == S_DONE) begin
            `N2T(i, 8, pass,  0, row_A, 0)
        end
    end

endmodule
