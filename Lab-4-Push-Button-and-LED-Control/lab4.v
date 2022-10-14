`timescale 1ns / 1ps
module lab4(
  input  clk,            // System clock at 100 MHz
  input  reset_n,        // System reset signal, in negative logic
  input  [3:0] usr_btn_raw,  // Four user pushbuttons
  output reg [3:0] usr_led   // Four yellow LEDs
);

    wire [3:0] usr_btn;
    debounce db_btn_0(.clk(clk), .in(usr_btn_raw[0]), .out(usr_btn[0]));
    debounce db_btn_1(.clk(clk), .in(usr_btn_raw[1]), .out(usr_btn[1]));
    debounce db_btn_2(.clk(clk), .in(usr_btn_raw[2]), .out(usr_btn[2]));
    debounce db_btn_3(.clk(clk), .in(usr_btn_raw[3]), .out(usr_btn[3]));

    reg signed [3:0] counter;
    reg [3:0] brightness;

    always @(posedge clk) begin
        if (!reset_n) begin
            counter <= 0;
        end
        else begin
            if (usr_btn[0] && counter < 7) begin
                counter <= counter + 1;
            end
            if (usr_btn[1] && counter > -8) begin
                counter <= counter - 1;
            end
            if (usr_btn[2] && brightness < 4) begin
                brightness <= brightness + 1;
            end
            if (usr_btn[3] && brightness > 0) begin
                brightness <= brightness - 1;
            end
        end
    end

    wire onoff;
    pwm_signal pwm(.clk(clk), .brightness(brightness), .onoff(onoff));

    integer i;
    always @(posedge clk) begin
        for (i = 0; i < 4; i = i+1) begin
            usr_led[i] <= counter[i] & onoff;
        end
    end
endmodule

module debounce(
    input  clk,
    input  in,
    output reg out
);
    integer cnt;
    reg stat;
    always @(posedge clk) begin
        if (stat !== in) begin
            stat <= in;
            cnt <= 0;
        end
        else if (stat !== out) begin
            if (cnt >= 10) begin
                out <= stat;
            end
            cnt <= cnt+1;
        end
    end
endmodule

module pwm_signal(
    input  clk,
    input  [3:0] brightness,
    output reg onoff
);
    integer cnt;

    initial begin
        onoff <= 1;
        cnt <= 0;
    end

    always @(posedge clk) begin
        cnt <= cnt == 1000000 ? 0 : cnt+1;
        case (brightness)
            0: onoff <= cnt <   50000;
            1: onoff <= cnt <  250000;
            2: onoff <= cnt <  500000;
            3: onoff <= cnt <  750000;
            4: onoff <= cnt < 1000000;
            default: onoff <= 1;
        endcase
    end
endmodule
