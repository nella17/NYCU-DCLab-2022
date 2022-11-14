`define STRCPY(i, size, in, of, out, off) \
    for(i = 0; i < size; i = i+1) \
        out[off+i] <= in[(i+of)*8 +: 8];
`define N2T(i, bits, in, out, off) \
    for(i = 0; i < bits; i = i+1) \
        out[off+i] <= in[i*4 +: 4] + ((in[i*4 +: 4] < 10) ? "0" : "A"-10);

`timescale 1ns / 1ps
module lab7(
    input  clk,
    input  reset_n,

    input  [3:0] usr_btn,
    output [3:0] usr_led,

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

    localparam HEAD = "The matrix multiplication result is:";
    localparam HEAD_LEN = 38+3, HEAD_POS = 0;
    localparam BODY = "[ ?????, ?????, ?????, ????? ]";
    localparam BODY_LEN = 30+3, BODY_POS = HEAD_POS + HEAD_LEN;
    localparam MEM_SIZE   = HEAD_LEN + BODY_LEN;

    reg [0:$clog2(MEM_SIZE)] send_counter;
    reg [7:0] data[0:MEM_SIZE-1];
    reg [0:HEAD_LEN*8-1] head = { HEAD, CRLF, NULL };
    reg [0:BODY_LEN*8-1] body = { BODY, CRLF, NULL };

    localparam [0:3] S_MAIN_WAIT = 0,
                     S_MAIN_READ = 1,
                     S_MAIN_READ_INCR = 2,
                     S_MAIN_MULT = 3,
                     S_MAIN_ADDI = 4,
                     S_MAIN_SAVE = 5,
                     S_MAIN_SAVE_INCR = 6,
                     S_MAIN_SHOW = 7,
                     S_MAIN_SHOW_HEAD = 8,
                     S_MAIN_SHOW_LOAD = 9,
                     S_MAIN_SHOW_BODY = 10,
                     S_MAIN_SHOW_INCR = 11,
                     S_MAIN_DONE = 12;
    reg [0:3] F, F_next;
    wire print_enable, print_done;

    reg [0:17] num [0:1], sum;
    reg [0:2] pn, pi, pj;
    wire [0:7] num_low [0:1];

    reg sram_write
    wire sram_enable = 1;
    reg [0:10] sram_addr;
    reg [0:17] sram_in;
    wire [0:17] sram_out;

    wire btn, btn_pressed;
    reg prev_btn;

    localparam [0:1] S_UART_IDLE = 0,
                     S_UART_WAIT = 1,
                     S_UART_SEND = 2,
                     S_UART_INCR = 3;
    reg U, U_next;
    wire transmit, received;
    wire [7:0] rx_byte, tx_byte;
    wire is_receiving, is_transmitting, recv_error;

    // main
    assign num_low[0] = num[0][0:7];
    assign num_low[1] = num[1][0:7];

    always @(posedge clk) begin
        if (~reset_n) begin
            pn <= 0;
            pi <= 0;
            pj <= 0;
        end else begin
            case (F)
                S_MAIN_READ_INCR:
                    if (pi ==
                S_MAIN_SHOW_BODY-1:
                    send_counter <= BODY_POS;
                default:
                    send_counter <= send_counter + (U_next == S_UART_INCR);
            endcase
        end
    end

    always @(posedge clk) begin
        if (~reset_n) begin
            sram_addr <= 0;
            sram_write <= 0;
            sram_enable <= 1;
        end else begin
            case (F)
                S_MAIN_READ_INCR:
                    if (pi ==
                S_MAIN_SHOW_BODY-1:
                    send_counter <= BODY_POS;
                default:
                    send_counter <= send_counter + (U_next == S_UART_INCR);
            endcase
        end
    end

    reg [0:$clog2(MEM_SIZE)] idx;
    always @(posedge clk) begin
        if (~reset_n) begin
            `STRCPY(idx, HEAD_LEN, head, 0, data, HEAD_POS)
            `STRCPY(idx, BODY_LEN, body, 0, data, BODY_POS)
        end
        // else if (P == S_MAIN_REPLY) begin
        //     `N2T(idx, 4, div_q, data, REPLY_STR+29)
        // end
    end

    assign print_enable = F == S_MAIN_SHOW;
    assign print_done = tx_byte == NULL;

    always @(posedge clk) begin
        F <= ~reset_n ? S_MAIN_WAIT : F_next;
    end

    always @(*) begin
        case (F)
            S_MAIN_WAIT:
                if (btn_pressed)
                    F_next = S_MAIN_READ;
                else
                    F_next = S_MAIN_WAIT;
            S_MAIN_READ:
                 F_next = S_MAIN_READ_INCR;
            S_MAIN_READ_INCR:
                 F_next = S_MAIN_READ;
            S_MAIN_MULT:
                 F_next = S_MAIN_SAVE;
            S_MAIN_ADDI:
                 F_next = S_MAIN_SAVE;
            S_MAIN_SAVE:
                 F_next = S_MAIN_SAVE_INCR;
            S_MAIN_SAVE_INCR:
                 F_next = S_MAIN_SHOW;
            S_MAIN_SHOW:
                 F_next = S_MAIN_SHOW_HEAD;
            S_MAIN_SHOW_HEAD:
                 F_next = S_MAIN_SHOW_LOAD;
            S_MAIN_SHOW_LOAD:
                 F_next = S_MAIN_SHOW_BODY;
            S_MAIN_SHOW_BODY:
                 F_next = S_MAIN_SHOW_INCR;
            S_MAIN_SHOW_INCR:
                 F_next = S_MAIN_SHOW_BODY;
            S_MAIN_DONE:
                 F_next = S_MAIN_DONE;
        endcase
    end

    always @(posedge clk) begin
        case (F_next)
            S_MAIN_SHOW_HEAD-1:
                send_counter <= HEAD_POS;
            S_MAIN_SHOW_BODY-1:
                send_counter <= BODY_POS;
            default:
                send_counter <= send_counter + (U_next == S_UART_INCR);
        endcase
    end

    // sram
    sram#(.DATA_WIDTH(18)) sram(.clk(clk), .we(sram_write), .en(sram_enable), .addr(sram_addr), .data_i(sram_in), .data_o(sram_out));

    // btns
    debounce db_btn(.clk(clk), .reset_n(reset_n), .in(usr_btn[1]), .out(btn));
    always @(posedge clk) begin
        prev_btn <= ~reset_n ? 0 : btn;
    end
    assign btn_pressed = ~prev_btn & btn;

    // LCD
    localparam row_A_init = "Data at [0x???] ";
    localparam row_B_init = " equals 0x????? ";

    reg [0:127] row_A = row_A_init;
    reg [0:127] row_B = row_B_init;

    LCD_module lcd(
        .clk(clk),
        .reset(~reset_n),
        .row_A(row_A),
        .row_B(row_B),
        .LCD_E(LCD_E),
        .LCD_RS(LCD_RS),
        .LCD_RW(LCD_RW),
        .LCD_D(LCD_D)
    );

    always @(posedge clk) begin
        if (~reset_n) begin
            row_A <= row_A_init;
            row_B <= row_B_init;
        end
    end

    // uart
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

    assign transmit = (U_next == S_UART_WAIT) || print_enable;
    assign tx_byte = data[send_counter];

    always @(posedge clk) begin
        U <= ~reset_n ? S_UART_IDLE : U_next;
    end

    always @(*) begin
        case (U)
            S_UART_IDLE:
                if (print_enable)
                    Q_next = S_UART_WAIT;
                else
                    Q_next = S_UART_IDLE;
            S_UART_WAIT:
                if (is_transmitting == 1)
                    Q_next = S_UART_SEND;
                else
                    Q_next = S_UART_WAIT;
            S_UART_SEND:
                if (is_transmitting == 0)
                    Q_next = S_UART_INCR;
                else
                    Q_next = S_UART_SEND;
            S_UART_INCR:
                if (print_done)
                    Q_next = S_UART_IDLE;
                else
                    Q_next = S_UART_WAIT;
        endcase
    end

endmodule
