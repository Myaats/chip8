`define GPU_FRAMEBUFFER_OFFSET 'h100
`define GPU_FRAMEBUFFER_LENGTH 'hFF
`define GPU_FRAMEBUFFER_END `GPU_FRAMEBUFFER_OFFSET + `GPU_FRAMEBUFFER_LENGTH

`define GPU_FRAMEBUFFER_WIDTH 64
`define GPU_FRAMEBUFFER_HEIGHT 32

`define get_vram_offset_for_fb(fb_x, fb_y) (fb_y % `GPU_FRAMEBUFFER_HEIGHT) * 8 + (fb_x % `GPU_FRAMEBUFFER_WIDTH) / 8
`define get_offset_for_fb(fb_x, fb_y) `GPU_FRAMEBUFFER_OFFSET + `get_vram_offset_for_fb(fb_x, fb_y)
