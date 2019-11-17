`include "cpu.v"
`include "timer.v"

module chip8(input wire CLK);
    // Timer tick wires
    wire timer_cpu_tick;
    wire timer_60hz_tick;

    // Components
    // Main CPU
    cpu cpu(.clk(CLK),
    .timer_cpu_tick(timer_cpu_tick),
    .timer_60hz_tick(timer_60hz_tick));
    // Hardware timer to send cycle ticks to the cpu
    timer timer(.clk(CLK),
    .timer_cpu_tick(timer_cpu_tick),
    .timer_60hz_tick(timer_60hz_tick));
endmodule
