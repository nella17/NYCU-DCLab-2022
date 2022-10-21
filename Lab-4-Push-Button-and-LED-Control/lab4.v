`timescale 1ns / 1ps
module lab4(
    input  clk,            // System clock at 100 MHz
    input  reset_n,        // System reset signal, in negative logic
    input  [3:0] usr_btn,  // Four user pushbuttons
    output reg [3:0] usr_led   // Four yellow LEDs
);

    wire [3:0] btn;
    genvar gi;
    generate for(gi = 0; gi < 4; gi = gi+1)
        debounce db_btn(.clk(clk), .reset_n(reset_n), .in(usr_btn[gi]), .out(btn[gi]));
    endgenerate

    reg [3:0] prev_btn;
    always @(posedge clk) begin
        if (!reset_n)
            prev_btn <= 0;
        else
            prev_btn <= btn;
    end

    wire [3:0] btn_pressed;
    generate for(gi = 0; gi < 4; gi = gi+1)
        assign btn_pressed[gi] = ~prev_btn[gi] && btn[gi];
    endgenerate

    reg signed [3:0] counter;
    reg [3:0] brightness;

    always @(posedge clk) begin
        if (!reset_n) begin
            counter <= 0;
            brightness <= 0;
        end else begin
            if (btn_pressed[0] && counter < 7)
                counter <= counter + 1;
            if (btn_pressed[1] && counter > -8)
                counter <= counter - 1;
            if (btn_pressed[2] && brightness < 4)
                brightness <= brightness + 1;
            if (btn_pressed[3] && brightness > 0)
                brightness <= brightness - 1;
        end
    end

    wire onoff;
    pwm_signal pwm(.clk(clk), .reset_n(reset_n), .brightness(brightness), .onoff(onoff));
    integer i;
    always @(posedge clk) begin
        for (i = 0; i < 4; i = i+1)
            usr_led[i] <= counter[i] & onoff;
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
        end else begin
            if (init == 0 || stat != in) begin
                init <= 1;
                stat <= in;
                cnt <= 0;
            end else if (stat != out) begin
                if (cnt < 10)
                    cnt <= cnt+1;
                else
                    out <= stat;
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
        end else begin
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
