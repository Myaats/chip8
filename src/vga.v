`include "gpu_utils.v"

`define VGA_HORIZONTAL_SIZE 640
`define VGA_VERTICAL_SIZE 480

`define VGA_HORIZONTAL_BLANKING_SIZE 155
`define VGA_VERTICAL_BLANKING_SIZE 45

`define VGA_HORIZONTAL_TOTAL_SIZE `VGA_HORIZONTAL_SIZE + `VGA_HORIZONTAL_BLANKING_SIZE
`define VGA_VERTICAL_TOTAL_SIZE `VGA_VERTICAL_SIZE + `VGA_VERTICAL_BLANKING_SIZE

`define VGA_HORIZONTAL_SYNC_START `VGA_HORIZONTAL_SIZE + 16
`define VGA_HORIZONTAL_SYNC_END `VGA_HORIZONTAL_SIZE + 16 + 96

`define VGA_VERTICAL_SYNC_START `VGA_VERTICAL_SIZE + 10
`define VGA_VERTICAL_SYNC_END `VGA_VERTICAL_SIZE + 10 + 2

module vga(input wire clk,
           input wire timer_vga_tick,

           output wire [3:0] vga_r,
           output wire [3:0] vga_g,
           output wire [3:0] vga_b,

           output reg [11:0] memory_addr,
           input wire [7:0] memory_data,

           output wire vga_hsync,
           output wire vga_vsync);

    reg [15:0] horizontal_count = 0;
    reg [15:0] vertical_count = 0;


    assign vga_hsync = (horizontal_count >= `VGA_HORIZONTAL_SYNC_START && horizontal_count < `VGA_HORIZONTAL_SYNC_END);
    assign vga_vsync = (vertical_count >= `VGA_VERTICAL_SYNC_START && vertical_count < `VGA_VERTICAL_SYNC_END);

    wire drawing = horizontal_count < `VGA_HORIZONTAL_SIZE && vertical_count < `VGA_VERTICAL_SIZE;

    reg pixel_value;

    // 10x upscale
    wire [15:0] pixel_x = horizontal_count / 10;
    wire [15:0] pixel_y = vertical_count / 15;

    assign vga_r = (pixel_value && drawing) ? 'b1111 : 'b0000;
    assign vga_g = vga_r;
    assign vga_b = vga_r;

    always @(posedge timer_vga_tick) begin
        // Reset the horizontal counter when reaching the width + blanking size
        if (horizontal_count == `VGA_HORIZONTAL_TOTAL_SIZE - 1) begin
            horizontal_count <= 0;

             // Reset the vertical counter when reaching the height + blanking size
            if (vertical_count == `VGA_VERTICAL_TOTAL_SIZE - 1) begin
                vertical_count <= 0;

            // Otherwise increment the vertical counter
            end else begin
                vertical_count <= vertical_count + 1;
            end
        // Otherwise increment the horizontal counter
        end else begin
            horizontal_count <= horizontal_count + 1;
        end

        if (drawing) begin
            pixel_value <= memory_data[7 - (pixel_x % 8)];
            memory_addr <= `get_vram_offset_for_fb(pixel_x, pixel_y);
        end else begin
            pixel_value <= 0;
            memory_addr <= 0;
        end
    end

endmodule
