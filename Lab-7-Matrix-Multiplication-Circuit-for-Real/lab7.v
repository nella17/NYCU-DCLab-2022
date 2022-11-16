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
    // output [3:0] usr_led,

    // output LCD_RS,
    // output LCD_RW,
    // output LCD_E,
    // output [3:0] LCD_D,

    input  uart_rx,
    output uart_tx
);

    localparam INIT_DELAY = 100_000; // 1 msec @ 100 MHz
    reg [$clog2(INIT_DELAY):0] init_counter;

    // Initialization counter.
    always @(posedge clk) begin
        if (~reset_n)
            init_counter <= 0;
        else
            init_counter <= init_counter + (init_counter != INIT_DELAY);
    end

    localparam M_SIZE = 4;

    localparam CRLF = "\x0D\x0A";
    localparam CR = "\x0D";
    localparam LF = "\x0A";
    localparam NULL = "\x00";

    localparam HEAD = "The matrix multiplication result is:";
    localparam HEAD_LEN = 41, HEAD_POS = 0;
    localparam BODY = " [ ?????, ?????, ?????, ????? ]";
    localparam BODY_LEN = 34, BODY_POS = HEAD_POS + HEAD_LEN;
    localparam MEM_SIZE   = HEAD_LEN + BODY_LEN;

    reg [$clog2(MEM_SIZE):0] send_counter = 0;
    reg [7:0] data [0:MEM_SIZE-1];
    reg [0:HEAD_LEN*8-1] head = { CRLF, HEAD, CRLF, NULL };
    reg [0:BODY_LEN*8-1] body = { BODY, CRLF, NULL };

    localparam [4:0] S_MAIN_WAIT = 0,
                     S_MAIN_READ = 1,
                     S_MAIN_READ_WAIT = 2,
                     S_MAIN_READ_SAVE = 3,
                     S_MAIN_MULT = 4,
                     S_MAIN_ADDI = 5,
                     S_MAIN_SAVE = 6,
                     S_MAIN_SAVE_WAIT = 7,
                     S_MAIN_SAVE_INCR = 8,
                     S_MAIN_SHOW = 9,
                     S_MAIN_SHOW_HEAD = 10,
                     S_MAIN_SHOW_LOAD = 11,
                     S_MAIN_SHOW_WAIT = 12,
                     S_MAIN_SHOW_SAVE = 13,
                     S_MAIN_SHOW_CALC = 14,
                     S_MAIN_SHOW_NEXT = 15,
                     S_MAIN_SHOW_BODY = 16,
                     S_MAIN_SHOW_INCR = 17,
                     S_MAIN_DONE = 18;
    reg [4:0] F, F_next;
    wire print_enable, print_done;

    reg [17:0] num [0:1];
    reg [17:0] sum, prod;
    wire [7:0] num_low [0:1];

    reg [2:0] pn;
    reg [$clog2(M_SIZE)*2:0] pij;
    wire [$clog2(M_SIZE)-1:0] pi, pj;
    reg [$clog2(M_SIZE):0] pk;
    wire calc_done;

    reg [0:19] user_data_out = 0;

    wire sram_write;
    wire sram_enable;
    reg [10:0] sram_addr;
    reg [17:0] sram_in;
    wire [17:0] sram_out;

    wire btn, btn_pressed;
    reg prev_btn;

    localparam [1:0] S_UART_IDLE = 0,
                     S_UART_WAIT = 1,
                     S_UART_SEND = 2,
                     S_UART_INCR = 3;
    reg [1:0] U, U_next;
    wire transmit, received;
    wire [7:0] rx_byte, tx_byte;
    wire is_receiving, is_transmitting, recv_error;

    // main
    assign num_low[0] = num[0][7:0];
    assign num_low[1] = num[1][7:0];

    // matrix logic
    assign pi = pij[$clog2(M_SIZE)*2-1:$clog2(M_SIZE)*1];
    assign pj = pij[$clog2(M_SIZE)*1-1:$clog2(M_SIZE)*0];
    assign calc_done = pij[$clog2(M_SIZE)*2];
    always @(posedge clk) begin
        if (~reset_n) begin
            num[0] <= 0; num[1] <= 0; sum <= 0;
            pn <= 0; pij <= 0; pk <= 0;
        end else begin
            case (F)
                S_MAIN_READ_SAVE: begin
                    num[pn] <= sram_out;
                    pn <= pn + 1;
                end
                S_MAIN_MULT: begin
                    prod <= num_low[0] * num_low[1];
                    pn <= 0;
                    pk <= pk + 1;
                end
                S_MAIN_ADDI:
                    sum <= sum + prod;
                S_MAIN_SAVE_WAIT: begin
                    sum <= 0;
                    pk <= 0;
                    if (~calc_done)
                        pij <= pij + 1;
                end
                S_MAIN_SHOW_CALC: begin
                    pk <= pk + 1;
                    pij <= pij + 1;
                end
                S_MAIN_SHOW_INCR: begin
                    pk <= 0;
                    if (calc_done)
                        pij <= pij + 1;
                end
                default: ;
            endcase
        end
    end

    // sram logic
    assign sram_enable = 1;
    assign sram_write = (F == S_MAIN_SAVE_WAIT);
    always @(posedge clk) begin
        if (~reset_n) begin
            sram_addr <= 0;
        end else begin
            case (F)
                S_MAIN_READ: begin
                    case (pn)
                        0: sram_addr <= (pn * M_SIZE * M_SIZE) | (pi) | (pk * M_SIZE);
                        1: sram_addr <= (pn * M_SIZE * M_SIZE) | (pk) | (pj * M_SIZE);
                        default: ;
                    endcase
                end
                // S_MAIN_READ_SAVE:
                //     user_data_out <= sram_out;
                S_MAIN_SAVE: begin
                    sram_addr <= (2 * M_SIZE * M_SIZE) | (pi) | (pj * M_SIZE);
                    sram_in <= sum;
                end
                S_MAIN_SHOW_LOAD:
                    sram_addr <= (2 * M_SIZE * M_SIZE) | (pi) | (pj * M_SIZE);
                S_MAIN_SHOW_SAVE:
                    user_data_out <= sram_out;
                default: ;
            endcase
        end
    end

    // uart display
    reg [$clog2(MEM_SIZE):0] idx;
    always @(posedge clk) begin
        if (~reset_n) begin
            `STRCPY(idx, HEAD_LEN, head, 0, data, HEAD_POS)
            `STRCPY(idx, BODY_LEN, body, 0, data, BODY_POS)
        end
        else begin
            case (F)
                S_MAIN_SHOW_LOAD: begin
                    idx <= 2 + pj * M_SIZE;
                end
                S_MAIN_SHOW_CALC: begin
                    `N2T(idx, 5, user_data_out, data, BODY_POS + 3 + pj * 7)
                end
                default: ;
            endcase
        end
    end

    assign print_enable = (F != S_MAIN_SHOW_HEAD && F_next == S_MAIN_SHOW_HEAD) ||
                        (F != S_MAIN_SHOW_BODY && F_next == S_MAIN_SHOW_BODY);
    assign print_done = tx_byte == NULL;

    always @(posedge clk) begin
        F <= ~reset_n ? S_MAIN_WAIT : F_next;
    end

    // MAIN FSM
    always @(*) begin
        case (F)
            S_MAIN_WAIT:
                if (init_counter == INIT_DELAY && btn_pressed)
                    F_next = S_MAIN_READ;
                else
                    F_next = S_MAIN_WAIT;
            S_MAIN_READ:
                F_next = S_MAIN_READ_WAIT;
            S_MAIN_READ_WAIT:
                F_next = S_MAIN_READ_SAVE;
            S_MAIN_READ_SAVE:
                if (pn < 2)
                    F_next = S_MAIN_READ;
                else
                    F_next = S_MAIN_MULT;
            S_MAIN_MULT:
                F_next = S_MAIN_ADDI;
            S_MAIN_ADDI:
                if (pk < M_SIZE)
                    F_next = S_MAIN_READ;
                else
                    F_next = S_MAIN_SAVE;
            S_MAIN_SAVE:
                F_next = S_MAIN_SAVE_WAIT;
            S_MAIN_SAVE_WAIT:
                F_next = S_MAIN_SAVE_INCR;
            S_MAIN_SAVE_INCR:
                if (calc_done)
                    F_next = S_MAIN_SHOW;
                else
                    F_next = S_MAIN_READ;
            S_MAIN_SHOW:
                F_next = S_MAIN_SHOW_HEAD;
            S_MAIN_SHOW_HEAD:
                if (print_done)
                    F_next = S_MAIN_SHOW_LOAD;
                else
                    F_next = S_MAIN_SHOW_HEAD;
            S_MAIN_SHOW_LOAD:
                F_next = S_MAIN_SHOW_WAIT;
            S_MAIN_SHOW_WAIT:
                F_next = S_MAIN_SHOW_SAVE;
            S_MAIN_SHOW_SAVE:
                F_next = S_MAIN_SHOW_CALC;
            S_MAIN_SHOW_CALC:
                F_next = S_MAIN_SHOW_NEXT;
            S_MAIN_SHOW_NEXT:
                if (pk < M_SIZE)
                    F_next = S_MAIN_SHOW_LOAD;
                else
                    F_next = S_MAIN_SHOW_BODY;
            S_MAIN_SHOW_BODY:
                if (print_done)
                    F_next = S_MAIN_SHOW_INCR;
                else
                    F_next = S_MAIN_SHOW_BODY;
            S_MAIN_SHOW_INCR:
                if (~calc_done)
                    F_next = S_MAIN_DONE;
                else
                    F_next = S_MAIN_SHOW_LOAD;
            S_MAIN_DONE:
                F_next = S_MAIN_DONE;
            default:
                F_next = S_MAIN_WAIT;
        endcase
    end

    always @(posedge clk) begin
        if (F != S_MAIN_SHOW_HEAD && F_next == S_MAIN_SHOW_HEAD)
            send_counter <= HEAD_POS;
        else if (F != S_MAIN_SHOW_BODY && F_next == S_MAIN_SHOW_BODY)
            send_counter <= BODY_POS;
        else
            send_counter <= send_counter + (U_next == S_UART_INCR);
    end

    // sram
    sram #(.DATA_WIDTH(18)) sram(
        .clk(clk), .we(sram_write), .en(sram_enable),
        .addr(sram_addr), .data_i(sram_in), .data_o(sram_out)
    );

    // LED
    // assign usr_led = sram_out[3:0];

    // btns
    debounce db_btn(.clk(clk), .reset_n(reset_n), .in(usr_btn[1]), .out(btn));
    always @(posedge clk) begin
        prev_btn <= ~reset_n ? 0 : btn;
    end
    assign btn_pressed = ~prev_btn & btn;

    // LCD
    /*
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
    //*/

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
                if (print_done)
                    U_next = S_UART_IDLE;
                else
                    U_next = S_UART_WAIT;
            default:
                U_next = S_UART_IDLE;
        endcase
    end

endmodule
