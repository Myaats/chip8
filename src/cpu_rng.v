module cpu_rng(input wire clk,
               output reg [30:0] value = 0);

    // Simple PRBS31 impl
    always @(posedge clk) begin
        value <= { value[30:0], value[30] ^ value[27] };
    end

endmodule
