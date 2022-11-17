`timescale 1ns / 1ps

module lab7_tb();
    localparam CRLF = "\x0D\x0A";
    localparam CR = "\x0D";
    localparam LF = "\x0A";

    reg  sys_clk = 0;
    reg  reset = 0;

    reg  [3:0] btn = 4'b0;
    // wire [3:0] led;

    // wire LCD_RS, LCD_RW, LCD_E;
    // wire [3:0] LCD_D;

    reg  rx = 1;
    wire tx;

    lab7 uut(
        .clk(sys_clk),
        .reset_n(~reset),
        .usr_btn(btn),
        // .usr_led(led),
        // .LCD_RS(LCD_RS),
        // .LCD_RW(LCD_RW),
        // .LCD_E(LCD_E),
        // .LCD_D(LCD_D),
        .uart_rx(rx),
        .uart_tx(tx)
    );

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

    always #5 sys_clk <= ~sys_clk;

    localparam OUT_SIZE = 200;
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

    event read_trigger;
    event read_done_trigger;
    event done_trigger;
    initial begin
        @ (posedge read_de); -> read_trigger;
        @ (negedge read_de); -> read_done_trigger;
        $display("%s", out); out = 0;
        -> done_trigger;
    end

    reg [3:0] j;
    initial begin
        #10 -> reset_trigger;
        @ (reset_done_trigger);
        #100_000_000;
        #200 btn[1] = 1;
        @ (done_trigger);
        $finish;
    end

endmodule
