`include "cpu.v"

module chip8(input wire CLK);
    cpu cpu0(.clk(CLK));
endmodule
