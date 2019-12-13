`include "cpu.v"
`include "memory.v"
`include "timer.v"

module chip8(input wire clk);
    // Memory data
    wire mem_read;
    wire [11:0] mem_read_addr;
    wire [7:0] mem_read_data;
    wire mem_read_ack;
    wire mem_write;
    wire [11:0] mem_write_addr;
    wire [7:0] mem_write_data;

    // Timer tick wires
    wire timer_cpu_tick;
    wire timer_60hz_tick;

    // Components
    // Main CPU
    cpu cpu(.clk(clk),
    .timer_cpu_tick(timer_cpu_tick),
    .timer_60hz_tick(timer_60hz_tick),
    // CPU Memory
    .mem_read(mem_read),
    .mem_read_addr(mem_read_addr),
    .mem_read_data(mem_read_data),
    .mem_read_ack(mem_read_ack),
    .mem_write(mem_write),
    .mem_write_addr(mem_write_addr),
    .mem_write_data(mem_write_data));
    // Memory
    memory memory(.clk(clk),
    .read(mem_read),
    .read_addr(mem_read_addr),
    .read_data(mem_read_data),
    .read_ack(mem_read_ack),
    .write(mem_write),
    .write_addr(mem_write_addr),
    .write_data(mem_write_data));
    // Hardware timer to send cycle ticks to the cpu
    timer timer(.clk(clk),
    .timer_cpu_tick(timer_cpu_tick),
    .timer_60hz_tick(timer_60hz_tick));
endmodule
