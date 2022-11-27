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
    genvar gi;

    localparam row_A_init = "SD card cannot  ";
    localparam row_B_init = "be initialized! ";
    localparam row_A_idle = "Hit BTN2 to read";
    localparam row_B_idle = "the SD card ... ";
    localparam row_A_sear = "Search DLAB_TAG ";
    localparam row_A_cont = "Count word size ";
    localparam row_A_done = "Found ???? words";
    localparam row_B_done = "in the text file";

    reg [0:255] row = { row_A_init, row_B_init };
    wire [127:0] row_A = row[0:127];
    wire [127:0] row_B = row[127:255];

    wire [3:0] btn, btn_pressed;
    reg  [3:0] prev_btn;

    reg [127:0] passwd_hash = 128'he8cd0953abdfde433dfec7faa70df7f6;

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

    reg [0:8*8-1] md5_in = "53589793";
    wire md5_start = btn_pressed[3];
    wire md5_done;
    wire [0:8*16-1] md5_out;

    md5 md5(
        .clk(clk),
        .reset_n(reset_n),
        .in(md5_in),
        .start(md5_start),
        .done(md5_done),
        .out(md5_out)
    );

    always @(posedge clk) begin
        prev_btn <= ~reset_n ? 0 : btn;
    end
    assign btn_pressed = ~prev_btn & btn;

    always @(posedge clk) begin
        if (md5_done)
            passwd_hash <= md5_out;
    end

    reg [7:0] i;
    always @(posedge clk) begin
        if (~reset_n) begin
            row <= { row_A_init, row_B_init };
        end else begin
            `N2T(i, 32, passwd_hash,  0, row, 0)
        end
    end

endmodule
