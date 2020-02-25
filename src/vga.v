module vga(input wire clk,
           input wire timer_vga_tick,
           
           output reg [3:0] vga_r,
           output reg [3:0] vga_g,
           output reg [3:0] vga_b,
           
           output reg vga_vsync,
           output reg vga_hsync);

endmodule
