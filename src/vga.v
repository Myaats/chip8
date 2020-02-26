`define VGA_HORIZONTAL_SIZE 640
`define VGA_VERTICAL_SIZE 480

`define VGA_HORIZONTAL_BLANKING_SIZE 160
`define VGA_VERTICAL_BLANKING_SIZE 45

`define VGA_HORIZONTAL_TOTAL_SIZE `VGA_HORIZONTAL_SIZE + `VGA_HORIZONTAL_BLANKING_SIZE
`define VGA_VERTICAL_TOTAL_SIZE `VGA_VERTICAL_SIZE + `VGA_VERTICAL_BLANKING_SIZE

module vga(input wire clk,
           input wire timer_vga_tick,

           output reg [3:0] vga_r,
           output reg [3:0] vga_g,
           output reg [3:0] vga_b,

           output wire vga_hsync,
           output wire vga_vsync);

    reg [15:0] horizontal_count;
    reg [15:0] vertical_count;

    assign vga_hsync = horizontal_count == `VGA_HORIZONTAL_TOTAL_SIZE;
    assign vga_vsync = vertical_count == `VGA_VERTICAL_TOTAL_SIZE;

    always @(posedge timer_vga_tick) begin
        // Reset the horizontal counter when reaching the width + blanking size
        if (horizontal_count == `VGA_HORIZONTAL_TOTAL_SIZE) begin
            horizontal_count <= 0;

             // Reset the vertical counter when reaching the width + blanking size
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
