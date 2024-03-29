`define N2T(i, bits, in, out, off) \
    for(i = 0; i < bits; i = i+1) \
        out[8*(off+i) +: 8] <= in[i*4 +: 4] + ((in[i*4 +: 4] < 10) ? "0" : "A"-10);

parameter SIZE = 25;
parameter TICKS = 70_000_000;
parameter TEXT = "Fibo #?? is ????";

`timescale 1ns / 1ps
/////////////////////////////////////////////////////////
module lab5(
    input clk,
    input reset_n,
    input [3:0] usr_btn,
    output [3:0] usr_led,
    output LCD_RS,
    output LCD_RW,
    output LCD_E,
    output [3:0] LCD_D
);

    // turn off all the LEDs
    assign usr_led = 4'b0000;

    wire btn_level, btn_pressed;
    reg prev_btn_level;
    reg [0:127] row_A = TEXT;
    reg [0:127] row_B = TEXT;

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

    debounce btn_db(
        .clk(clk),
        .reset_n(reset_n),
        .in(usr_btn[3]),
        .out(btn_level)
    );

    always @(posedge clk) begin
        if (~reset_n)
            prev_btn_level <= 1;
        else
            prev_btn_level <= btn_level;
    end

    assign btn_pressed = (btn_level == 1 && prev_btn_level == 0);
    reg dir;
    always @(posedge clk) begin
        if (~reset_n)
            dir <= 0;
        else if (btn_pressed)
            dir <= ~dir;
    end

    reg [0:15] fibo [1:SIZE];
    reg done;
    reg [0:4] i;
    always @(posedge clk) begin
        if (~reset_n) begin
            done <= 0;
            fibo[1] <= 0;
            fibo[2] <= 1;
            i <= 3;
        end else if (~done) begin
            fibo[i] <= fibo[i-1] + fibo[i-2];
            i <= i+1;
            if (i == SIZE)
                done <= 1;
        end
    end

    reg [0:7] idx;
    wire [0:7] nxt = (idx == SIZE) ? 1 : idx+1;
    reg [0:$clog2(TICKS)] cnt;
    always @(posedge clk) begin
        if (~reset_n) begin
            idx <= 1;
            cnt <= 0;
        end else begin
            if (cnt < TICKS)
                cnt <= cnt + 1;
            else begin
                cnt <= 0;
                if (~dir)
                    idx <= (idx == SIZE) ? 1 : idx+1;
                else
                    idx <= (idx == 1) ? SIZE : idx-1;
            end
        end
    end

    reg [0:2] j;
    always @(posedge clk) begin
        if (~reset_n) begin
            row_A <= TEXT;
            row_B <= TEXT;
        end else if (done) begin
            `N2T(j, 2, idx, row_A, 6)
            `N2T(j, 2, nxt, row_B, 6)
            `N2T(j, 4, fibo[idx], row_A, 12)
            `N2T(j, 4, fibo[nxt], row_B, 12)
        end
    end

endmodule

module debounce #(
    parameter CNT = 10
)(
    input  clk,
    input  reset_n,
    input  in,
    output reg out
);
    reg init, stat;
    reg [0:$clog2(CNT)] cnt;
    always @(posedge clk) begin
        if (~reset_n) begin
            init <= 0;
        end else begin
            if (init == 0 || stat != in) begin
                init <= 1;
                stat <= in;
                cnt <= 0;
            end else if (stat != out) begin
                if (cnt < CNT)
                    cnt <= cnt+1;
                else
                    out <= stat;
            end
        end
    end
endmodule
