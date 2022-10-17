`timescale 1ns / 1ps
module lab4(
    input  clk,            // System clock at 100 MHz
    input  reset_n,        // System reset signal, in negative logic
    input  [3:0] usr_btn,  // Four user pushbuttons
    output reg [3:0] usr_led   // Four yellow LEDs
);

    wire [3:0] btn;
    debounce db_btn_0(.clk(clk), .reset_n(reset_n), .in(usr_btn[0]), .out(btn[0]));
    debounce db_btn_1(.clk(clk), .reset_n(reset_n), .in(usr_btn[1]), .out(btn[1]));
    debounce db_btn_2(.clk(clk), .reset_n(reset_n), .in(usr_btn[2]), .out(btn[2]));
    debounce db_btn_3(.clk(clk), .reset_n(reset_n), .in(usr_btn[3]), .out(btn[3]));
    reg [3:0] prev_btn;

    reg signed [3:0] counter;
    reg [3:0] brightness;

    always @(posedge clk) begin
        if (!reset_n) begin
            counter <= 0;
            prev_btn <= 0;
        end
        else begin
            if (prev_btn[0] && !btn[0] && counter < 7) begin
                counter <= counter + 1;
            end
            if (prev_btn[1] && !btn[1] && counter > -8) begin
                counter <= counter - 1;
            end
            if (prev_btn[2] && !btn[2] && brightness < 4) begin
                brightness <= brightness + 1;
            end
            if (prev_btn[3] && !btn[3] && brightness > 0) begin
                brightness <= brightness - 1;
            end
            prev_btn <= btn;
        end
    end

    wire onoff;
    pwm_signal pwm(.clk(clk), .reset_n(reset_n), .brightness(brightness), .onoff(onoff));
    integer i;
    always @(posedge clk) begin
        for (i = 0; i < 4; i = i+1) begin
            usr_led[i] <= counter[i] & onoff;
        end
    end
endmodule

module debounce(
    input  clk,
    input  reset_n,
    input  in,
    output reg out
);
    reg init, stat;
    integer cnt;
    always @(posedge clk) begin
        if (!reset_n) begin
            init <= 0;
        end
        else begin
            if (init == 0 || stat != in) begin
                init <= 1;
                stat <= in;
                cnt <= 0;
            end
            else if (stat != out) begin
                if (cnt >= 10) begin
                    out <= stat;
                end
                cnt <= cnt+1;
            end
        end
    end
endmodule

module pwm_signal(
    input  clk,
    input  reset_n,
    input  [3:0] brightness,
    output reg onoff
);
    integer cnt;
    localparam TICK = 10000;

    always @(posedge clk) begin
        if (!reset_n) begin
            onoff <= 1;
            cnt <= 0;
        end
        else begin
            cnt <= cnt == TICK * 100 ? 0 : cnt+1;
            case (brightness)
                0: onoff <= cnt < TICK *   5;
                1: onoff <= cnt < TICK *  25;
                2: onoff <= cnt < TICK *  50;
                3: onoff <= cnt < TICK *  75;
                4: onoff <= cnt < TICK * 100;
                default: onoff <= 1;
            endcase
        end
    end
endmodule
