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
    reg  rx = 1;
    wire tx;

    localparam OUT_SIZE = 30;
    reg [8*OUT_SIZE-1:0] out = 0;
    reg [7:0] tmp_in, tmp_out;

    reg read = 0;
    wire read_de;
    debounce #(.CNT(32_000)) de_read(.clk(sys_clk), .reset_n(~reset), .in(read), .out(read_de));

    reg [3:0] tx_cnt;
    initial begin
        forever begin
            @ (negedge tx);
            read = 1;
            for (tx_cnt = 0; tx_cnt < 8; tx_cnt = tx_cnt+1)
                #104_167 tmp_out[tx_cnt] = tx;
            out = { out[8*(OUT_SIZE-1)-1:0], tmp_out };
            read = 0;
        end
    end

    event uart_read_trigger;
    event uart_read_done_trigger;
    event uart_done_trigger;
    initial begin
        @ (posedge read_de); -> uart_read_trigger;
        @ (negedge read_de); -> uart_read_done_trigger;
        $display("%s", out); out = 0;
        -> uart_done_trigger;
    end

    lab9 lab9(
        .clk(sys_clk),
        .reset_n(~reset),
        .usr_btn(btn),
        .LCD_RS(LCD_RS),
        .LCD_RW(LCD_RW),
        .LCD_E(LCD_E),
        .LCD_D(LCD_D),
        .uart_rx(rx),
        .uart_tx(tx)
    );

    initial begin
        #10 -> reset_trigger;
        @ (reset_done_trigger);
        #150 btn[3] = 1;
        @ (posedge lab9.md5_done);
        #50;
        $display("%s", lab9.row);
        @ (uart_done_trigger);
        $finish;
    end

endmodule
