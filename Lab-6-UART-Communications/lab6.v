`define STRCPY(i, size, in, of, out, off) \
    for(i = 0; i < size; i = i+1) \
        out[off+i] <= in[(i+of)*8 +: 8];
`define N2T(i, bits, in, out, off) \
    for(i = 0; i < bits; i = i+1) \
        out[off+i] <= in[i*4 +: 4] + ((in[i*4 +: 4] < 10) ? "0" : "A"-10);

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of CS, National Chiao Tung University
// Engineer: Chun-Jen Tsai
// 
// Create Date: 2018/10/10 16:10:38
// Design Name: UART I/O example for Arty
// Module Name: lab6
// Project Name: 
// Target Devices: Xilinx FPGA @ 100MHz
// Tool Versions: 
// Description: 
// 
// The parameters for the UART controller are 9600 baudrate, 8-N-1-N
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module lab6(
    input  clk,
    input  reset_n,
    input  [3:0] usr_btn,
    output [3:0] usr_led,
    input  uart_rx,
    output uart_tx
);
    localparam CRLF = "\x0D\x0A";
    localparam CR = "\x0D";
    localparam LF = "\x0A";
    localparam NULL = "\x00";

    localparam [2:0] S_MAIN_INIT     = 0,
                     S_MAIN_PROMPT   = 1,
                     S_MAIN_READ_NUM = 2,
                     S_MAIN_NXT      = 3,
                     S_MAIN_DIV      = 4,
                     S_MAIN_REPLY    = 5;
    localparam [1:0] S_UART_IDLE = 0,
                     S_UART_WAIT = 1,
                     S_UART_SEND = 2,
                     S_UART_INCR = 3;
    localparam [2:0] S_DIV_IDLE = 0,
                     S_DIV_MUL  = 1,
                     S_DIV_SUB  = 2,
                     S_DIV_DEC  = 3,
                     S_DIV_DONE = 4;
    localparam INIT_DELAY = 100_000; // 1 msec @ 100 MHz

    localparam PROMPT = "Enter 1st decimal number: ";
    localparam PROMPT_STR = 0;
    localparam PROMPT_LEN = 29;
    localparam REPLY = "The integer quotient is: 0x0000.";
    localparam REPLY_STR  = PROMPT_STR + PROMPT_LEN;
    localparam REPLY_LEN  = 37;
    localparam MEM_SIZE   = PROMPT_LEN + REPLY_LEN;
    localparam ORDER_LEN  = 3;
    localparam BIT_SIZE   = 16;

    // declare system variables
    wire enter_pressed;
    wire print_enable, print_done;
    wire div_enable, div_done;
    reg [$clog2(MEM_SIZE):0] send_counter;
    reg [2:0] P, P_next;
    reg [1:0] Q, Q_next;
    reg [2:0] D, D_next;
    reg [$clog2(INIT_DELAY):0] init_counter;
    reg [7:0] data[0:MEM_SIZE-1];
    reg [0:PROMPT_LEN*8-1] msg1 = { CRLF, PROMPT, NULL };
    reg [0:REPLY_LEN*8-1]  msg2 = { CRLF, REPLY, CRLF, NULL };
    reg [0:BIT_SIZE-1] num_reg;  // The key-in number register
    reg [2:0]  key_cnt;  // The key strokes counter
    reg [0:BIT_SIZE-1] number[0:1];
    reg [0:1]  number_cnt;
    reg [0:ORDER_LEN*2*8-1] order = { "1st", "2nd" };
    reg signed [0:5] div_idx;
    reg [0:BIT_SIZE-1] div_q, div_r;

    // declare UART signals
    wire transmit;
    wire received;
    wire [7:0] rx_byte;
    reg  [7:0] rx_temp;  // if recevied is true, rx_temp latches rx_byte for ONLY ONE CLOCK CYCLE!
    wire [7:0] tx_byte;
    wire [7:0] echo_key; // keystrokes to be echoed to the terminal
    wire is_num_key;
    wire is_receiving;
    wire is_transmitting;
    wire recv_error;

    /* The UART device takes a 100MHz clock to handle I/O at 9600 baudrate */
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

    // Initializes some strings.
    // System Verilog has an easier way to initialize an array,
    // but we are using Verilog 2001 :(
    //
    integer idx;

    always @(posedge clk) begin
        if (~reset_n) begin
            `STRCPY(idx, PROMPT_LEN, msg1, 0, data, PROMPT_STR)
            `STRCPY(idx, REPLY_LEN , msg2, 0, data, REPLY_STR )
        end
        else if (P == S_MAIN_PROMPT) begin
            `STRCPY(idx, ORDER_LEN , order, number_cnt * ORDER_LEN, data, PROMPT_STR+8)
        end
        else if (P == S_MAIN_REPLY) begin
            `N2T(idx, 4, div_q, data, REPLY_STR+29)
        end
    end

    // Combinational I/O logics of the top-level system
    assign usr_led = usr_btn;
    assign enter_pressed = (rx_temp == CR); // don't use rx_byte here!

    // ------------------------------------------------------------------------
    // Main FSM that reads the UART input and triggers
    // the output of the string "Hello, World!".
    always @(posedge clk) begin
        if (~reset_n)
            P <= S_MAIN_INIT;
        else
            P <= P_next;
    end

    always @(*) begin // FSM next-state logic
        case (P)
            S_MAIN_INIT: // Wait for initial delay of the circuit.
                if (init_counter < INIT_DELAY)
                    P_next = S_MAIN_INIT;
                else
                    P_next = S_MAIN_PROMPT;
            S_MAIN_PROMPT: // Print the prompt message.
                if (print_done)
                    P_next = S_MAIN_READ_NUM;
                else
                    P_next = S_MAIN_PROMPT;
            S_MAIN_READ_NUM: // wait for <Enter> key.
                if (enter_pressed)
                    P_next = S_MAIN_NXT;
                else
                    P_next = S_MAIN_READ_NUM;
            S_MAIN_NXT:
                if (number_cnt == 1)
                    P_next = S_MAIN_PROMPT;
                else
                    P_next = S_MAIN_DIV;
            S_MAIN_DIV:
                if (div_done)
                    P_next = S_MAIN_REPLY;
                else
                    P_next = S_MAIN_DIV;
            S_MAIN_REPLY: // Print the hello message.
                if (print_done)
                    P_next = S_MAIN_INIT;
                else
                    P_next = S_MAIN_REPLY;
        endcase
    end

    // FSM output logics: print string control signals.
    assign print_enable = (P != S_MAIN_PROMPT && P_next == S_MAIN_PROMPT) ||
                          (P == S_MAIN_DIV && P_next == S_MAIN_REPLY);
    assign print_done = (tx_byte == NULL);

    // Initialization counter.
    always @(posedge clk) begin
        if (P == S_MAIN_INIT)
            init_counter <= init_counter + 1;
        else
            init_counter <= 0;
    end
    // End of the FSM of the print string controller
    // ------------------------------------------------------------------------

    // ------------------------------------------------------------------------
    // FSM of the controller that sends a string to the UART.
    always @(posedge clk) begin
        if (~reset_n)
            Q <= S_UART_IDLE;
        else
            Q <= Q_next;
    end

    always @(*) begin // FSM next-state logic
        case (Q)
            S_UART_IDLE: // wait for the print_string flag
                if (print_enable)
                    Q_next = S_UART_WAIT;
                else
                    Q_next = S_UART_IDLE;
            S_UART_WAIT: // wait for the transmission of current data byte begins
                if (is_transmitting == 1)
                    Q_next = S_UART_SEND;
                else
                    Q_next = S_UART_WAIT;
            S_UART_SEND: // wait for the transmission of current data byte finishes
                if (is_transmitting == 0)
                    Q_next = S_UART_INCR; // transmit next character
                else
                    Q_next = S_UART_SEND;
            S_UART_INCR:
                if (print_done)
                    Q_next = S_UART_IDLE; // string transmission ends
                else
                    Q_next = S_UART_WAIT;
        endcase
    end

    // FSM output logics: UART transmission control signals
    assign transmit = (Q_next == S_UART_WAIT ||
                      (P == S_MAIN_READ_NUM && received) ||
                       print_enable);
    assign is_num_key = ("0" <= rx_byte) && (rx_byte <= "9") && (key_cnt < 5);
    assign echo_key = (is_num_key || rx_byte == CR) ? rx_byte : NULL;
    assign tx_byte  = ((P == S_MAIN_READ_NUM) && received) ? echo_key : data[send_counter];

    // UART send_counter control circuit
    always @(posedge clk) begin
        case (P_next)
            S_MAIN_INIT:
                send_counter <= PROMPT_STR;
            S_MAIN_NXT:
                send_counter <= PROMPT_STR;
            S_MAIN_DIV:
                send_counter <= REPLY_STR;
            default:
                send_counter <= send_counter + (Q_next == S_UART_INCR);
        endcase
    end
    // End of the FSM of the print string controller
    // ------------------------------------------------------------------------

    // ------------------------------------------------------------------------
    // UART input logic
    // Decimal number input will be saved in num1 or num2.
    always @(posedge clk) begin
        if (~reset_n || (P == S_MAIN_INIT || P == S_MAIN_PROMPT))
            key_cnt <= 0;
        else if (received && is_num_key)
            key_cnt <= key_cnt + 1;
    end

    always @(posedge clk)begin
        if (~reset_n)
            num_reg <= 0;
        else if (P == S_MAIN_INIT || P == S_MAIN_PROMPT)
            num_reg <= 0;
        else if (received && is_num_key)
            num_reg <= (num_reg * 10) + (rx_byte - "0");
    end

    always @(posedge clk) begin
        if (~reset_n || (P == S_MAIN_INIT))
            number_cnt <= 0;
        else if (enter_pressed && P_next == S_MAIN_NXT)
            number_cnt <= number_cnt + 1;
        else if (P == S_MAIN_NXT)
            number[number_cnt-1] <= num_reg;
    end

    // The following logic stores the UART input in a temporary buffer.
    // The input character will stay in the buffer for one clock cycle.
    always @(posedge clk) begin
        rx_temp <= (received) ? rx_byte : NULL;
    end
    // End of the UART input logic
    // ------------------------------------------------------------------------

    assign div_enable = P_next == S_MAIN_DIV;
    assign div_done = D_next == S_DIV_DONE;

    always @(posedge clk) begin
        if (~reset_n)
            D <= S_DIV_IDLE;
        else
            D <= D_next;
    end

    always @(*) begin
        case (D)
            S_DIV_IDLE:
                if (div_enable)
                    D_next = S_DIV_MUL;
                else
                    D_next = S_DIV_IDLE;
            S_DIV_MUL:
                if (div_idx >= BIT_SIZE)
                    D_next = S_DIV_DONE;
                else
                    D_next = S_DIV_SUB;
            S_DIV_SUB:
                D_next = S_DIV_DEC;
            S_DIV_DEC:
                D_next = S_DIV_MUL;
            S_DIV_DONE:
                if (P == S_MAIN_INIT)
                    D_next = S_DIV_IDLE;
                else
                    D_next = S_DIV_DONE;
        endcase
    end

    always @(posedge clk) begin
        if (~reset_n || (D == S_DIV_IDLE)) begin
            div_idx <= 0;
            div_q <= 0;
            div_r <= 0;
        end else if (D == S_DIV_MUL) begin
            div_r <= div_r * 2 + number[0][div_idx];
        end else if (D == S_DIV_SUB) begin
            if (div_r >= number[1]) begin
                div_r <= div_r - number[1];
                div_q[div_idx] <= 1;
            end
        end else if (D == S_DIV_DEC) begin
            div_idx <= div_idx + 1;
        end
    end

endmodule
