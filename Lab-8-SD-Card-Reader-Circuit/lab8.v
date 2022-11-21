`define N2T(i, bits, in, out, off) \
    for(i = 0; i < bits; i = i+1) \
        out[off+i] <= in[i*4 +: 4] + ((in[i*4 +: 4] < 10) ? "0" : "A"-10);

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Chiao Tung University
// Engineer: Chun-Jen Tsai
// 
// Create Date: 2017/05/08 15:29:41
// Design Name: 
// Module Name: lab6
// Project Name: 
// Target Devices: 
// Tool Versions:
// Description: The sample top module of lab 6: sd card reader. The behavior of
//              this module is as follows
//              1. When the SD card is initialized, display a message on the LCD.
//                 If the initialization fails, an error message will be shown.
//              2. The user can then press usr_btn[2] to trigger the sd card
//                 controller to read the super block of the sd card (located at
//                 block # 8192) into the SRAM memory.
//              3. During SD card reading time, the four LED lights will be turned on.
//                 They will be turned off when the reading is done.
//              4. The LCD will then displayer the sector just been read, and the
//                 first byte of the sector.
//              5. Everytime you press usr_btn[2], the next byte will be displayed.
// 
// Dependencies: clk_divider, LCD_module, debounce, sd_card
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module lab8(
    // General system I/O ports
    input  clk,
    input  reset_n,
    input  [3:0] usr_btn,
    output [3:0] usr_led,

    // SD card specific I/O ports
    output spi_ss,
    output spi_sck,
    output spi_mosi,
    input  spi_miso,

    // 1602 LCD Module Interface
    output LCD_RS,
    output LCD_RW,
    output LCD_E,
    output [3:0] LCD_D
);

    localparam [3:0] S_MAIN_INIT = 0,
                     S_MAIN_IDLE = 1,
                     S_MAIN_WAIT = 2,
                     S_MAIN_READ = 3,
                     S_MAIN_CLER = 4,
                     S_MAIN_LOAD = 5,
                     S_MAIN_CALC = 6,
                     S_MAIN_INCR = 7,
                     S_MAIN_NEXT = 8,
                     S_MAIN_DONE = 9;

    localparam LF = "\x0A";
    localparam BEGIN = "DLAB_TAG\x0A";
    localparam END = "DLAB_END\x0A";
    localparam TARGET_SIZE = 3;

    localparam row_A_init = "SD card cannot  ";
    localparam row_B_init = "be initialized! ";
    localparam row_A_idle = "Hit BTN2 to read";
    localparam row_B_idle = "the SD card ... ";
    localparam row_A_done = "Found ???? words";
    localparam row_B_done = "in the text file";

    // Declare system variables
    wire btn_level, btn_pressed;
    reg  prev_btn_level;

    reg  [3:0] P, P_next;
    reg  [127:0] row_A = row_A_init;
    reg  [127:0] row_B = row_B_init;

    reg [3:0] begin_idx, end_idx;
    wire is_begin, is_end;
    wire isLF, isLetter;
    reg  [0:16] word_counter;
    reg  [10:0] word_size;
    reg  [7:0] data_byte;

    reg  [9:0] sd_counter;
    reg  [31:0] blk_addr;

    // Declare SD card interface signals
    wire clk_sel;
    wire clk_500k;
    reg  rd_req;
    reg  [31:0] rd_addr;
    wire init_finished;
    wire [7:0] sd_dout;
    wire sd_valid;

    // Declare the control/data signals of an SRAM memory block
    wire [7:0] data_in;
    wire [7:0] data_out;
    wire [8:0] sram_addr;
    wire       sram_we, sram_en;

    assign clk_sel = (init_finished)? clk : clk_500k; // clock for the SD controller
    assign usr_led = 4'h00;

    clk_divider#(200) clk_divider0(
        .clk(clk),
        .reset(~reset_n),
        .clk_out(clk_500k)
    );

    debounce btn_db0(
        .clk(clk),
        .reset_n(reset_n),
        .in(usr_btn[2]),
        .out(btn_level)
    );

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

    sd_card sd_card0(
        .cs(spi_ss),
        .sclk(spi_sck),
        .mosi(spi_mosi),
        .miso(spi_miso),

        .clk(clk_sel),
        .rst(~reset_n),
        .rd_req(rd_req),
        .block_addr(rd_addr),
        .init_finished(init_finished),
        .dout(sd_dout),
        .sd_valid(sd_valid)
    );

    sram ram0(
        .clk(clk),
        .we(sram_we),
        .en(sram_en),
        .addr(sram_addr),
        .data_i(data_in),
        .data_o(data_out)
    );

    //
    // Enable one cycle of btn_pressed per each button hit
    //
    always @(posedge clk) begin
        if (~reset_n)
            prev_btn_level <= 0;
        else
            prev_btn_level <= btn_level;
    end

    assign btn_pressed = (btn_level == 1 && prev_btn_level == 0)? 1 : 0;

    // ------------------------------------------------------------------------
    // The following code sets the control signals of an SRAM memory block
    // that is connected to the data output port of the SD controller.
    // Once the read request is made to the SD controller, 512 bytes of data
    // will be sequentially read into the SRAM memory block, one byte per
    // clock cycle (as long as the sd_valid signal is high).
    assign sram_we = sd_valid;          // Write data into SRAM when sd_valid is high.
    assign sram_en = 1;                 // Always enable the SRAM block.
    assign data_in = sd_dout;           // Input data always comes from the SD controller.
    assign sram_addr = sd_counter[8:0]; // Set the driver of the SRAM address signal.
    // End of the SRAM memory block
    // ------------------------------------------------------------------------

    // ------------------------------------------------------------------------
    // FSM of the SD card reader that reads the super block (512 bytes)
    always @(posedge clk) begin
        if (~reset_n) begin
            P <= S_MAIN_INIT;
        end else begin
            P <= P_next;
        end
    end

    always @(*) begin // FSM next-state logic
        case (P)
        S_MAIN_INIT: // wait for SD card initialization
            if (init_finished == 1)
                P_next = S_MAIN_IDLE;
            else
                P_next = S_MAIN_INIT;
        S_MAIN_IDLE: // wait for button click
            if (btn_pressed == 1)
                P_next = S_MAIN_WAIT;
            else
                P_next = S_MAIN_IDLE;
        S_MAIN_WAIT: // issue a rd_req to the SD controller until it's ready
            P_next = S_MAIN_READ;
        S_MAIN_READ: // wait for the input data to enter the SRAM buffer
            if (sd_counter == 512)
                P_next = S_MAIN_CLER;
            else
                P_next = S_MAIN_READ;
        S_MAIN_CLER:
            P_next = S_MAIN_LOAD;
        S_MAIN_LOAD:
            P_next = S_MAIN_CALC;
        S_MAIN_CALC:
            P_next = S_MAIN_INCR;
        S_MAIN_INCR:
            if (sd_counter == 512)
                P_next = S_MAIN_NEXT;
            else
                P_next = S_MAIN_CALC;
        S_MAIN_NEXT:
            if (is_end)
                P_next = S_MAIN_DONE;
            else
                P_next = S_MAIN_WAIT;
        S_MAIN_DONE:
            P_next = S_MAIN_DONE;
        default:
            P_next = S_MAIN_IDLE;
        endcase
    end

    // FSM output logic: controls the 'rd_req' and 'rd_addr' signals.
    always @(*) begin
        rd_req = (P == S_MAIN_WAIT);
        rd_addr = blk_addr;
    end

    always @(posedge clk) begin
        if (~reset_n)
            blk_addr <= 32'h2000;
        else
            blk_addr <= blk_addr; // In lab 6, change this line to scan all blocks
    end

    // FSM output logic: controls the 'sd_counter' signal.
    // SD card read address incrementer
    always @(posedge clk) begin
        if (~reset_n || (P == S_MAIN_CLER) || (P == S_MAIN_NEXT))
            sd_counter <= 0;
        else if ((P == S_MAIN_READ && sd_valid) || (P == S_MAIN_CALC))
            sd_counter <= sd_counter + 1;
    end

    assign is_begin = BEGIN[begin_idx] == LF;
    always @(posedge clk) begin
        if (~reset_n || (P == S_MAIN_IDLE))
            begin_idx <= 0;
        else if (~is_begin && data_byte == BEGIN[begin_idx])
            begin_idx <= begin_idx + 1;
    end

    assign is_end = END[end_idx] == LF;
    always @(posedge clk) begin
        if (~reset_n || (P == S_MAIN_IDLE))
            end_idx <= 0;
        else if (~is_end && data_byte == END[end_idx])
            end_idx <= end_idx + 1;
    end

    assign isLF = data_byte == LF;
    assign isLetter = ("A" <= data_byte && data_byte <= "Z") ||
                ("a" <= data_byte && data_byte <= "z") || (data_byte == "_");
    always @(posedge clk) begin
        if (~reset_n || (P == S_MAIN_IDLE))
            word_size <= 0;
        else if (is_begin && ~is_end && P == S_MAIN_CALC)
            word_size <= ~isLetter ? 0 : word_size + 1;
    end
    always @(posedge clk) begin
        if (~reset_n || (P == S_MAIN_IDLE))
            word_counter <= 0;
        else if (is_begin && ~is_end && P == S_MAIN_INCR && ~isLetter && word_size == TARGET_SIZE)
            word_counter <= word_counter + 1;
    end

    // ------------------------------------------------------------------------
    // LCD Display function.
    reg [2:0] i;
    always @(posedge clk) begin
        if (~reset_n) begin
            row_A <= row_A_init;
            row_B <= row_B_init;
        end else if (P == S_MAIN_IDLE) begin
            row_A <= row_A_idle;
            row_B <= row_B_idle;
        end else if (P != S_MAIN_DONE) begin
            row_A <= row_A_done;
            row_B <= row_B_done;
        end else begin
            `N2T(i, 4, word_counter, row_A, 6)
        end
    end
    // End of the LCD display function
    // ------------------------------------------------------------------------

endmodule
