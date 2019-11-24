`include "platform-speficic.v"

`define CPU_SPEED 500 // Hertz

module timer(input wire clk,
             output wire timer_cpu_tick,
             output wire timer_60hz_tick);
    
    reg [31:0] timer_cpu_countdown = 0;
    reg [31:0] timer_60hz_countdown = 0;
    
    parameter TIMER_CPU_TOP  = `CLOCK_SPEED / `CPU_SPEED;
    parameter TIMER_60HZ_TOP = `CLOCK_SPEED / 60;
    
    always @(posedge clk) begin
        // CPU countdown timer for each instruction cycle
        if (timer_cpu_countdown == 0) timer_cpu_countdown <= TIMER_CPU_TOP;
        else timer_cpu_countdown <= timer_cpu_countdown - 1;
        
        // 60Hz countdown timer used for delay and sound inside the chip8 processor
        if (timer_60hz_countdown == 0) timer_60hz_countdown <= TIMER_60HZ_TOP;
        else timer_60hz_countdown <= timer_60hz_countdown - 1;
    end
    
    // Set the outputs to high when the countdowns reach 0
    assign timer_cpu_tick  = timer_cpu_countdown == 0;
    assign timer_60hz_tick = timer_60hz_countdown == 0;
    
endmodule
