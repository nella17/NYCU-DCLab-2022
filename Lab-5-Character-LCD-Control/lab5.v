`define TICKS 70000000
`define N2T(i, bits, in, out, off) \
    for(i = 0; i < bits; i = i+1) \
        out[8*(off+i) +: 8] <= in[i*4 +: 4] + ((in[i*4 +: 4] < 10) ? "0" : "A"-10);

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
    reg [0:127] row_A = "Fibo #?? is ????";
    reg [0:127] row_B = "Fibo #?? is ????";

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

    debounce btn_db0(
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

    reg [0:15] fibo [1:25];
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
            if (i == 25)
                done <= 1;
        end
    end

    reg [0:7] idx;
    wire [0:7] nxt = (idx == 25) ? 1 : idx+1;
    integer cnt;
    always @(posedge clk) begin
        if (~reset_n) begin
            idx <= 1;
            cnt <= 0;
        end else begin
            if (cnt < `TICKS)
                cnt <= cnt + 1;
            else begin
                idx <= idx + (dir ? 1 : -1);
                if (~dir)
                    idx <= (idx == 25) ? 1 : idx+1;
                else
                    idx <= (idx == 1) ? 25 : idx-1;
                cnt <= 0;
            end
        end
    end

    integer j;
    always @(posedge clk) begin
        if (~reset_n) begin
            row_A <= "Fibo #?? is ????";
            row_B <= "Fibo #?? is ????";
        end else if (done) begin
            `N2T(j, 2, idx, row_A, 6)
            `N2T(j, 2, nxt, row_B, 6)
            `N2T(j, 4, fibo[idx], row_A, 12)
            `N2T(j, 4, fibo[nxt], row_B, 12)
        end
    end

endmodule

module debounce(
    input  clk,
    input  reset_n,
    input  in,
    output reg out
);
    reg init, stat;
    integer cnt;
    always @(posedge clk) begin
        if (~reset_n) begin
            init <= 0;
        end
        else begin
            if (init == 0 || stat != in) begin
                init <= 1;
                stat <= in;
                cnt <= 0;
            end
            else if (stat != out) begin
                if (cnt >= 10) begin
                    out <= stat;
                end
                cnt <= cnt+1;
            end
        end
    end
endmodule
