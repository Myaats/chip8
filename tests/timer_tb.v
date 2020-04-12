`include "timer.v"

`include "platform-speficic.v"
`include "utils.v"

`define PER_CPU_TICK `CLOCK_SPEED / `CPU_SPEED
`define PER_60HZ_TICK `CLOCK_SPEED / 60

module timer_tb;
    reg clk = 0;

    wire timer_cpu_tick;
    wire timer_60hz_tick;

    timer timer(.clk(clk),
    .timer_cpu_tick(timer_cpu_tick),
    .timer_60hz_tick(timer_60hz_tick));

    // 100 KHz clock
    initial
        forever #1 clk = ~clk;

    integer i, should_cpu_tick, should_60hz_tick;
    initial begin
        $dumpfile(`VCD_PATH);
        $dumpvars;

        `assert_eq(timer_cpu_tick, 1);
        `assert_eq(timer_60hz_tick, 1);

        for (i = 1; i < `CLOCK_SPEED * 4; i++) begin
            // Check that the CPU timer ticked
            #2 should_cpu_tick = i % $unsigned(`PER_CPU_TICK) == 0;
            `assert_eq(timer_cpu_tick, should_cpu_tick);
            // Check that the 60Hz timer ticked
            should_60hz_tick = i % $unsigned(`PER_60HZ_TICK) == 0;
            `assert_eq(timer_60hz_tick, should_60hz_tick);
        end

        $finish;
    end
endmodule
