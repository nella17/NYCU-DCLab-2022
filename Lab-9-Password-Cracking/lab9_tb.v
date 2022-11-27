`timescale 1ns / 1ps
module lab9_tb ();

    reg  sys_clk = 0;
    always #5 sys_clk <= ~sys_clk;

    reg  reset = 0;
    event reset_trigger;
    event reset_done_trigger;
    initial begin
        forever begin
            @ (reset_trigger);
            @ (negedge sys_clk);
            reset = 1;
            @ (negedge sys_clk);
            reset = 0;
            -> reset_done_trigger;
        end
    end

    reg  [3:0] btn = 4'b0;
    wire LCD_RS, LCD_RW, LCD_E;
    wire [3:0] LCD_D;
    lab9 lab9(
        .clk(sys_clk),
        .reset_n(~reset),
        .usr_btn(btn),
        .LCD_RS(LCD_RS),
        .LCD_RW(LCD_RW),
        .LCD_E(LCD_E),
        .LCD_D(LCD_D)
    );

    initial begin
        #10 -> reset_trigger;
        @ (reset_done_trigger);
        #150 btn[3] = 1;
        @ (posedge lab9.md5_done);
        #10;
        $finish;
    end

endmodule
