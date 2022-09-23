module mmult(
    input  clk,                 // Clock signal.
    input  reset_n,             // Reset signal (negative logic).
    input  enable,              // Activation signal for matrix
                                // multiplication (tells the circuit
                                // that A and B are ready for use).
    input  [0:9*8-1] A_mat,     // A matrix.
    input  [0:9*8-1] B_mat,     // B matrix.
    output reg valid,               // Signals that the output is valid
                                // to read.
    output reg [0:9*17-1] C_mat // The result of A x B.
);

    reg [2:0]   counter;
    wire        mult;
    integer     x, y, i, j, k;
 
    assign mult = |(counter ^ 3);
    
    always @(posedge clk, negedge reset_n) begin
        if (!enable || !reset_n) begin
            counter <= 0;
            valid <= 0;
            C_mat <= { 9{ 17'b0 } };
        end
        else if (mult) begin
            for(x = 0; x < 3; x = x+1) begin
                for(y = 0; y < 3; y = y+1) begin
                    k = x*3 + y;
                    i = x*3 + counter;
                    j = counter*3 + y;
                    C_mat[17*k +: 17] <= C_mat[17*k +: 17] + A_mat[8*i +: 8] * B_mat[8*j +: 8];
                end
            end
            counter <= counter + mult;
        end
        else begin
            valid <= 1;
        end
    end

endmodule