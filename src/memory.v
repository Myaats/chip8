`include "gpu_utils.v"

module memory(input wire clk,
              input wire read,
              input wire [11:0] read_addr,
              output reg [7:0] read_data = 0,
              output reg read_ack = 0,
              input wire write,
              input wire [11:0] write_addr,
              input wire [7:0] write_data,
              // GPU inputs
              input wire gpu_read,
              input wire [11:0] gpu_read_addr,
              output wire [7:0] gpu_read_data,
              output reg gpu_read_ack = 0,
              input wire gpu_write,
              input wire [11:0] gpu_write_addr,
              input wire [7:0] gpu_write_data,
              // VGA data
              input wire [11:0] vga_addr,
              output reg [7:0] vga_data
           );

    parameter MEMORY_SIZE = 4096;
    parameter VRAM_SIZE = `GPU_FRAMEBUFFER_LENGTH;

    reg [7:0] mem[0:MEMORY_SIZE - 1];
    reg [7:0] vram[0:VRAM_SIZE - 1];

    integer i;
    initial begin
        for (i = 0; i < MEMORY_SIZE; i = i + 1) begin
            mem[i] = 0;
        end

        for (i = 0; i < VRAM_SIZE; i = i + 1) begin
            vram[i] = 0;
        end

        // Put the font data in the upper part of the reserved memory
        $readmemh("assets/font.hex", mem, 'h0);
        // ROM for PONG
        $readmemh("assets/pong.hex", mem, 'h200);
    end

    wire [11:0] combined_write_addr = gpu_write ? gpu_write_addr : write_addr;
    wire [11:0] combined_write_data = gpu_write ? gpu_write_data : write_data;

    assign gpu_read_data = read_data;

    // Main memory
    always @(posedge clk) begin
        // Reset acknowledgement
        read_ack <= 0;
        gpu_read_ack <= 0;

        // Read memory
        if (read || gpu_read) begin
            read_data <= mem[gpu_read ? gpu_read_addr : read_addr];

            if (gpu_read)
                gpu_read_ack <= 1;
            else
                read_ack <= 1;
        end

        // VGA memory access
        vga_data <= vram[vga_addr];

        // Having multiple mem storing statements will break Quartus' synth, but this seems to work
        // The CPU will never write anything while the GPU is working so this should not cause any issues
        if (write || gpu_write) begin
            mem[combined_write_addr] <= combined_write_data;

            if (combined_write_addr >= `GPU_FRAMEBUFFER_OFFSET && combined_write_addr < `GPU_FRAMEBUFFER_END) begin
                vram[combined_write_addr - `GPU_FRAMEBUFFER_OFFSET] <= combined_write_data;
            end
        end
    end
endmodule
