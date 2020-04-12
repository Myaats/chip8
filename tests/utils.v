`define assert_eq(a, b) \
    if (a !== b) begin \
        $display("ASSERTION FAILED in %m: a: ", a, " != b"); \
        $finish_and_return(1); \
    end

`define print_framebuffer(memory) \
    for (fb_y=0; fb_y < 32; fb_y++) begin \
        for (fb_x=0; fb_x < 64; fb_x++) begin \
            if (memory.mem[`get_offset_for_fb(fb_x, fb_y)][7 - (fb_x % 8)]) \
                $write("██"); \
            else \
                $write("  "); \
        end \
        $write("\n"); \
    end