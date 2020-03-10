`define VGA_HORIZONTAL_SIZE 640
`define VGA_VERTICAL_SIZE 480

`define VGA_HORIZONTAL_BLANKING_SIZE 160
`define VGA_VERTICAL_BLANKING_SIZE 45

`define VGA_HORIZONTAL_TOTAL_SIZE `VGA_HORIZONTAL_SIZE + `VGA_HORIZONTAL_BLANKING_SIZE
`define VGA_VERTICAL_TOTAL_SIZE `VGA_VERTICAL_SIZE + `VGA_VERTICAL_BLANKING_SIZE

`define VGA_HORIZONTAL_SYNC_START 16
`define VGA_HORIZONTAL_SYNC_END 16 + 96

`define VGA_VERTICAL_SYNC_START `VGA_VERTICAL_SIZE + 10
`define VGA_VERTICAL_SYNC_END `VGA_VERTICAL_SIZE + 10 + 2

module vga(input wire clk,
           input wire timer_vga_tick,

           output wire [3:0] vga_r,
           output wire [3:0] vga_g,
           output wire [3:0] vga_b,

           output wire memory_read,
           output wire [11:0] memory_addr,
           input wire [7:0] memory_data,

           output wire vga_hsync,
           output wire vga_vsync);

    reg [15:0] horizontal_count;
    reg [15:0] vertical_count;

    assign vga_hsync = ~((horizontal_count >= `VGA_HORIZONTAL_SYNC_START) & (horizontal_count < `VGA_HORIZONTAL_SYNC_END));
    assign vga_vsync = ~((vertical_count >= `VGA_VERTICAL_SYNC_START) & (vertical_count < `VGA_VERTICAL_SYNC_END));

    wire drawing = horizontal_count >= `VGA_HORIZONTAL_BLANKING_SIZE && vertical_count < `VGA_VERTICAL_SIZE;
    wire [15:0] pixel_x = drawing ? horizontal_count - `VGA_HORIZONTAL_BLANKING_SIZE : 0;

    assign memory_read = drawing;
    assign memory_addr = vertical_count * 64 + pixel_x / 8;

    wire pixel_value = memory_data[(vertical_count * 64 + pixel_x) % 8];

    assign vga_r = (pixel_value && drawing) ? 'b1111 : 'b0000;
    assign vga_g = vga_r;
    assign vga_b = vga_r;

    always @(posedge timer_vga_tick) begin
        // Reset the horizontal counter when reaching the width + blanking size
        if (horizontal_count == `VGA_HORIZONTAL_TOTAL_SIZE) begin
            horizontal_count <= 0;

             // Reset the vertical counter when reaching the height + blanking size
            if (vertical_count == `VGA_VERTICAL_TOTAL_SIZE) begin
                vertical_count <= 0;

            // Otherwise increment the vertical counter
            end else begin
                vertical_count <= vertical_count + 1;
            end
        // Otherwise increment the horizontal counter
        end else begin
            horizontal_count <= horizontal_count + 1;
        end
    end

endmodule
