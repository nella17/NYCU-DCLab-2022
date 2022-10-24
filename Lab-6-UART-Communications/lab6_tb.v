`timescale 1ns / 1ps

module lab6_tb();
    localparam CRLF = "\x0D\x0A";
    localparam CR = "\x0D";
    localparam LF = "\x0A";

    reg  sys_clk = 0;
    reg  reset = 0;
    reg  [3:0] btn = 4'b0;
    reg  rx = 1;
    wire tx;
    wire [3:0] led;

    lab6 uut(
        .clk(sys_clk),
        .reset_n(~reset),
        .usr_btn(btn),
        .uart_rx(rx),
        .uart_tx(tx),
        .usr_led(led)
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

    localparam IN_SIZE = 10;
    reg [0:8*IN_SIZE-1] in = {
        "1234", CRLF,
        "15", CRLF
    };
    localparam OUT_SIZE = 40;
    reg [8*OUT_SIZE-1:0] out = 0;
    reg [7:0] tmp_in, tmp_out;

    reg read = 0;
    wire read_de;
    debounce #(.CNT(32_000)) de_read(.clk(sys_clk), .reset_n(~reset), .in(read), .out(read_de));

    reg [0:3] tx_cnt;
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
    event input_done_trigger;
    initial begin
        @ (posedge read_de); -> read_trigger;
        @ (negedge read_de); -> read_done_trigger;
        @ (input_done_trigger);
        $display("%s", out); out = 0;
        /*@ (posedge read_de);*/ -> read_trigger;
        @ (negedge read_de); -> read_done_trigger;
        @ (input_done_trigger);
        $display("%s", out); out = 0;
        /*@ (posedge read_de);*/ -> read_trigger;
        @ (negedge read_de); -> read_done_trigger;
        $display("%s", out); out = 0;
    end

    reg [0:$clog2(IN_SIZE)] i;
    reg [0:3] j;
    initial begin
        #10 -> reset_trigger;
        @ (read_done_trigger);

        for(i = 0; i < IN_SIZE; i = i + 1) begin
            #104_167 rx = 0;
            tmp_in = in[i*8 +: 8];
            for (j = 0; j < 8; j = j+1)
                #104_167 rx = tmp_in[j];
            #104_167 rx = 1;
            #104_167;
            #104_167;
            #104_167;
            if (tmp_in == LF) begin
                -> input_done_trigger;
                #104_167;
                @ (read_done_trigger);
            end
        end

        $finish;
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
            end else if (stat !== out) begin
                if (cnt < CNT)
                    cnt <= cnt+1;
                else
                    out <= stat;
            end
        end
    end
endmodule
