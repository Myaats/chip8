`include "cpu.v"
`include "gpu.v"
`include "memory.v"
`include "timer.v"
`include "utils.v"

module cpu_tb;
    reg clk = 0;

    // GPU Wires
    wire [3:0] gpu_cmd;
    wire [11:0] gpu_draw_offset;
    wire [7:0] gpu_draw_x;
    wire [7:0] gpu_draw_y;
    wire [7:0] gpu_draw_length;
    wire gpu_cmd_submitted;
    wire gpu_collision;
    wire gpu_ready;

    // Memory data
    wire mem_read;
    wire [11:0] mem_read_addr;
    wire [7:0] mem_read_data;
    wire mem_read_ack;
    wire mem_write;
    wire [11:0] mem_write_addr;
    wire [7:0] mem_write_data;
    // GPU memory data
    wire gpu_mem_read;
    wire [11:0] gpu_mem_read_addr;
    wire [7:0] gpu_mem_read_data;
    wire gpu_mem_read_ack;
    wire gpu_mem_write;
    wire [11:0] gpu_mem_write_addr;
    wire [7:0] gpu_mem_write_data;

    // Timer tick wires
    wire timer_cpu_tick;
    wire timer_60hz_tick;
    wire timer_vga_tick;

    // Keypad stubs
    reg [15:0] keypad_value = 0;

    // VGA stubs
    reg [11:0] vga_mem_addr = 0;
    wire [7:0] vga_mem_data;

    initial
        forever #1 clk = ~clk;

    // Components
    // Main CPU
    cpu cpu(.clk(clk),
    .timer_cpu_tick(timer_cpu_tick),
    .timer_60hz_tick(timer_60hz_tick),
    .keypad_value(keypad_value),
    // CPU GPU
    .gpu_cmd(gpu_cmd),
    .gpu_draw_offset(gpu_draw_offset),
    .gpu_draw_x(gpu_draw_x),
    .gpu_draw_y(gpu_draw_y),
    .gpu_draw_length(gpu_draw_length),
    .gpu_cmd_submitted(gpu_cmd_submitted),
    .gpu_collision(gpu_collision),
    .gpu_ready(gpu_ready),
    // CPU Memory
    .mem_read(mem_read),
    .mem_read_addr(mem_read_addr),
    .mem_read_data(mem_read_data),
    .mem_read_ack(mem_read_ack),
    .mem_write(mem_write),
    .mem_write_addr(mem_write_addr),
    .mem_write_data(mem_write_data));

    gpu gpu(.clk(clk),
    .gpu_cmd(gpu_cmd),
    .gpu_draw_offset(gpu_draw_offset),
    .gpu_draw_x(gpu_draw_x),
    .gpu_draw_y(gpu_draw_y),
    .gpu_draw_length(gpu_draw_length),
    .gpu_cmd_submitted(gpu_cmd_submitted),
    .gpu_collision(gpu_collision),
    .gpu_ready(gpu_ready),
    .gpu_mem_read(gpu_mem_read),
    .gpu_mem_read_addr(gpu_mem_read_addr),
    .gpu_mem_read_data(gpu_mem_read_data),
    .gpu_mem_read_ack(gpu_mem_read_ack),
    .gpu_mem_write(gpu_mem_write),
    .gpu_mem_write_addr(gpu_mem_write_addr),
    .gpu_mem_write_data(gpu_mem_write_data));

    // Memory
    memory memory(.clk(clk),
    .read(mem_read),
    .read_addr(mem_read_addr),
    .read_data(mem_read_data),
    .read_ack(mem_read_ack),
    .write(mem_write),
    .write_addr(mem_write_addr),
    .write_data(mem_write_data),
    .gpu_read(gpu_mem_read),
    .gpu_read_addr(gpu_mem_read_addr),
    .gpu_read_data(gpu_mem_read_data),
    .gpu_read_ack(gpu_mem_read_ack),
    .gpu_write(gpu_mem_write),
    .gpu_write_addr(gpu_mem_write_addr),
    .gpu_write_data(gpu_mem_write_data),
    .vga_addr(vga_mem_addr),
    .vga_data(vga_mem_data));

    // Hardware timer to send cycle ticks to the cpu
    timer timer(.clk(clk),
    .timer_cpu_tick(timer_cpu_tick),
    .timer_60hz_tick(timer_60hz_tick),
    .timer_vga_tick(timer_vga_tick));

    integer fb_x, fb_y;
    initial begin
        $dumpfile(`VCD_PATH);
        $dumpvars;

        #300000;

        `print_framebuffer(memory);

        $finish;
    end

endmodule
