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
    output [3:0] LCD_D,

    input  uart_rx,
    output uart_tx
);
    localparam CRLF = "\x0D\x0A";
    localparam CR = "\x0D";
    localparam LF = "\x0A";
    localparam NULL = "\x00";
    localparam DEBUG = 1;

    genvar gi;

    reg [127:0] passwd_hash = 128'h0113df004fea93a20fb02c1fa5fda95d; // 07654231

    localparam [0:1] S_IDLE = 0,
                     S_CALC = 1,
                     S_SHOW = 2,
                     S_DONE = 3;
    reg [0:1] F = S_IDLE, F_next;
    reg [31:0] pass;
    reg found;

    wire uart_done;

    localparam row_B_hash = "????????????????";
    localparam row_A_idle = "Hit BTN3 to run ";
    localparam row_A_sear = "Search md5(PASS)";
    localparam row_A_done = "Passwd: xxxxxxxx";
    localparam row_B_done = "Time: yyyyyyy ms";

    reg [127:0] row_A = row_A_idle;
    reg [127:0] row_B = row_B_hash;
    wire [0:255+8*5] row = { row_A, CRLF, row_B, CRLF, NULL };

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

    wire md5_start = F == S_CALC;
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
            F <= S_IDLE;
        else
            F <= F_next;
    end
    always @(*) begin
        case (F)
        S_IDLE:
            if (DEBUG || btn_pressed[3])
                F_next = S_CALC;
            else
                F_next = S_IDLE;
        S_CALC:
            if (found)
                F_next = S_SHOW;
            else
                F_next = S_CALC;
        S_SHOW:
            if (uart_done)
                F_next = S_DONE;
            else
                F_next = S_SHOW;
        S_DONE:
            F_next = S_DONE;
        default:
            F_next = S_IDLE;
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
        else if (F == S_IDLE)
            `N2T(i, 16, passwd_hash, 16, row_B, 0)
        else if (F == S_CALC)
            { row_A, row_B } <= { row_A_done, row_B_done };
        else if (F == S_SHOW) begin
            `N2T(i, 8, pass,  0, row_A, 0)
        end
    end

    // uart
    reg [5:0] idx;
    wire print_enable, print_done;

    localparam [1:0] S_UART_IDLE = 0,
                     S_UART_WAIT = 1,
                     S_UART_SEND = 2,
                     S_UART_INCR = 3;
    reg [1:0] U, U_next;
    wire transmit, received;
    wire [7:0] rx_byte;
    wire [7:0] tx_byte = row[idx*8 +: 8];
    wire is_receiving, is_transmitting, recv_error;

    assign print_enable = F_next == S_SHOW;
    assign print_done = U == S_UART_INCR;
    assign transmit = (U_next == S_UART_WAIT) || print_enable;

    assign uart_done = tx_byte == NULL;

    always @(posedge clk) begin
        idx <= ~reset_n ? 0 : idx + print_done;
    end

    uart uart(
        .clk(clk),
        .rst(~reset_n),
        .rx(uart_rx),
        .tx(uart_tx),
        .transmit(transmit),
        .tx_byte(tx_byte),
        .received(received),
        .rx_byte(rx_byte),
        .is_receiving(is_receiving),
        .is_transmitting(is_transmitting),
        .recv_error(recv_error)
    );

    always @(posedge clk) begin
        U <= ~reset_n ? S_UART_IDLE : U_next;
    end

    always @(*) begin
        case (U)
            S_UART_IDLE:
                if (print_enable)
                    U_next = S_UART_WAIT;
                else
                    U_next = S_UART_IDLE;
            S_UART_WAIT:
                if (is_transmitting == 1)
                    U_next = S_UART_SEND;
                else
                    U_next = S_UART_WAIT;
            S_UART_SEND:
                if (is_transmitting == 0)
                    U_next = S_UART_INCR;
                else
                    U_next = S_UART_SEND;
            S_UART_INCR:
                U_next = S_UART_IDLE;
            default:
                U_next = S_UART_IDLE;
        endcase
    end

endmodule
