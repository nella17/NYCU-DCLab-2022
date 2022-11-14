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
