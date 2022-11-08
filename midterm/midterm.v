`define N2T(i, bits, in, out, off) \
    for(i = 0; i < bits; i = i+1) \
        out[8*(off+i) +: 8] <= in[i*4 +: 4] + ((in[i*4 +: 4] < 10) ? "0" : "A"-10);

parameter PLAY_SEC = 10;
parameter PLAY_TICKS = 100_000_000;
parameter RESET_TICKS = 50_000_000;

`timescale 1ns / 1ps
/////////////////////////////////////////////////////////
module midterm(
    input clk,
    input reset_n,
    input [3:0] usr_btn_raw,
    output [3:0] usr_led,
    output LCD_RS,
    output LCD_RW,
    output LCD_E,
    output [3:0] LCD_D
);

    reg [0:$clog2(PLAY_TICKS)] play_cnt = 0;
    reg signed [0:$clog2(PLAY_SEC)] sec_cnt = PLAY_SEC;
    reg [0:2] reset_counter = 0;
    reg [0:$clog2(RESET_TICKS)] reset_cnt = 0;
    reg soft_reset = 0;

    localparam [0:3] S_MAIN_INIT    = 0,
                     S_MAIN_WAIT    = 1,
                     S_MAIN_PLAY    = 2,
                     S_MAIN_OVER    = 3;
    reg [0:3] P = S_MAIN_INIT, P_next = S_MAIN_INIT;
    wire initialing, playing, done;

    wire [3:0] btn;
    reg [3:0] prev_btn;
    wire [3:0] btn_pressed;

    reg right_shoot = 0, wrong_shoot = 0;
    reg [0:8] wac = " ";

    wire new_zombie;
    reg [0:4] init_i = 0;
    reg [0:1] init_j = 0;
    reg zombie_new_idx = 0;
    reg [0:16] zombies = 0;
    reg [0:3] zombie_cnt [0:2];

    genvar gi;

    // LOGIC
    assign initialing = P == S_MAIN_INIT;
    assign playing = P == S_MAIN_PLAY;
    assign done = sec_cnt <= 0;
    always @(posedge clk) begin
        if (reset || initialing) begin
            play_cnt <= 0;
            sec_cnt <= PLAY_SEC;
        end else if (playing) begin
            if (play_cnt < PLAY_TICKS) begin
                play_cnt <= play_cnt + 1;
            end else begin
                play_cnt <= 0;
                sec_cnt <= sec_cnt - 1;
            end
        end
    end

    always @(posedge clk) begin
        if (reset || !playing) begin
            right_shoot <= 0;
            wrong_shoot <= 0;
        end else if (btn_pressed[0]) begin
            right_shoot <=  zombies[15];
            wrong_shoot <= ~zombies[15];
        end else if (btn_pressed[3]) begin
            right_shoot <= ~zombies[15];
            wrong_shoot <=  zombies[15];
        end else begin
            right_shoot <= 0;
            wrong_shoot <= 0;
        end
    end

    // FST
    always @(posedge clk) begin
        if (reset)
            P <= S_MAIN_INIT;
        else
            P <= P_next;
    end

    always @(*) begin // FSM next-state logic
        case (P)
            S_MAIN_INIT:
                if (init_i >= 16)
                    P_next <= S_MAIN_WAIT;
                else
                    P_next <= S_MAIN_INIT;
            S_MAIN_WAIT:
                if (btn_pressed[0])
                    P_next <= S_MAIN_PLAY;
                else
                    P_next <= S_MAIN_WAIT;
            S_MAIN_PLAY:
                if (done)
                    P_next <= S_MAIN_OVER;
                else
                    P_next <= S_MAIN_PLAY;
            S_MAIN_OVER:
                    P_next <= S_MAIN_OVER;
        endcase
    end

    // zombie
    always @(posedge clk) begin
        if (reset) begin
            init_i <= 0;
        end else if (init_i < 16) begin
            init_i <= init_i + 1;
        end
    end

    assign new_zombie = initialing || right_shoot;
    always @(posedge clk) begin
        if (reset) begin
            init_j <= 0;
            zombie_new_idx <= 0;
        end else if (new_zombie) begin
            if (init_j) begin
                init_j <= 0;
                zombie_new_idx <= ~zombie_new_idx;
            end else begin
                init_j <= 1;
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            zombies <= 0;
        end else if (new_zombie) begin
            zombies <= { zombie_new_idx, zombies[0:15] };
        end
    end

    reg signed [0:3] i;
    always @(posedge clk) begin
        if (reset || initialing) begin
            wac <= " ";
            zombie_cnt[0] <= 0;
            zombie_cnt[1] <= 0;
            zombie_cnt[2] <= 0;
        end else if (right_shoot) begin
            for (i = 2; i > 0; i = i - 1)
                zombie_cnt[i] <= zombie_cnt[i] < 9 ? zombie_cnt[i] + (zombie_cnt[i-1] == 9) : 0;
            zombie_cnt[0] <= zombie_cnt[0] < 9 ? zombie_cnt[0] + 1 : 0;
            wac <= " ";
        end else if (wrong_shoot) begin
            wac <= "x";
        end
    end

    // reset
    always @(posedge clk) begin
        if (~reset_n) begin
            reset_counter <= 0;
            reset_cnt <= 0;
            soft_reset <= 0;
        end else begin
            if (~btn[3]) begin
                soft_reset <= reset_counter == 4;
                reset_counter <= 0;
                reset_cnt <= 0;
            end else begin
                soft_reset <= 0;
                if (reset_cnt < RESET_TICKS)
                    reset_cnt <= reset_cnt + 1;
                else begin
                    reset_cnt <= 0;
                    reset_counter <= reset_counter + (reset_counter < 4);
                end
            end
        end
    end
    assign reset = (~reset_n) || soft_reset;

    // btns
    generate for(gi = 0; gi < 4; gi = gi+1) begin
        debounce db_btn(.clk(clk), .reset_n(reset_n), .in(usr_btn_raw[gi]), .out(btn[gi]));
    end endgenerate
    always @(posedge clk) begin
        if (~reset_n)
            prev_btn <= 0;
        else
            prev_btn <= btn;
    end
    assign btn_pressed = ~prev_btn & btn;

    // LED
    generate for(gi = 0; gi < 4; gi = gi+1) begin
        assign usr_led[3-gi] = reset_counter >= gi+1;
    end endgenerate

    // LCD
    localparam row_A_init = "PRESS BTN0      ";
    localparam row_B_init = "TO START        ";
    localparam row_A_done = "   GAME OVER    ";
    localparam row_B_done = "KILL 000 ZOMBIES";

    reg [0:127] row_A = row_A_init;
    reg [0:127] row_B = row_B_init;

    LCD_module lcd0(
        .clk(clk),
        .reset(reset),
        .row_A(row_A),
        .row_B(row_B),
        .LCD_E(LCD_E),
        .LCD_RS(LCD_RS),
        .LCD_RW(LCD_RW),
        .LCD_D(LCD_D)
    );

    reg [0:3] lcd_i;
    reg [0:2] lcd_draw;
    assign sps = lcd_i == 15 ? wac : " ";
    always @(posedge clk) begin
        if (reset || initialing) begin
            lcd_i <= 0;
            row_A <= row_A_init;
            row_B <= row_B_init;
            lcd_draw <= 0;
        end else if (playing) begin
            if (lcd_i == 0)
                row_A[lcd_i*8 +: 8] <= sec_cnt == 10 ? "1" : "0";
            else if (lcd_i == 1)
                row_A[lcd_i*8 +: 8] <= sec_cnt == 10 ? "0" : ("0" + sec_cnt);
            else
                row_A[lcd_i*8 +: 8] <= zombies[lcd_i] ? "o" : sps;
            row_B[lcd_i*8 +: 8] <= zombies[lcd_i] ? sps : "o";
            lcd_i <= lcd_i + 1;
        end else if (done) begin
            if (lcd_draw == 0) begin
                row_A <= row_A_done;
                row_B <= row_B_done;
                lcd_i <= 0;
                lcd_draw <= 1;
            end else if (lcd_draw == 1) begin
                if (lcd_i < 3) begin
                    lcd_draw <= 2;
                    row_B[8*(7-lcd_i) +: 8] <= "0" + zombie_cnt[lcd_i];
                end else begin
                    lcd_draw <= 3;
                end
            end else if (lcd_draw == 2) begin
                lcd_draw <= 1;
                lcd_i <= 1;
            end
        end
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
            end else if (stat != out) begin
                if (cnt < CNT)
                    cnt <= cnt+1;
                else
                    out <= stat;
            end
        end
    end
endmodule
