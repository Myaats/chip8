`include "gpu_cmd.v"

`define GPU_FRAMEBUFFER_OFFSET 'h100
`define GPU_FRAMEBUFFER_LENGTH 'hFF

`define GPU_FRAMEBUFFER_WIDTH 64
`define GPU_FRAMEBUFFER_HEIGHT 32

`define get_offset_for_fb(fb_x, fb_y) ((fb_y % `GPU_FRAMEBUFFER_HEIGHT) * 4 + (fb_x % `GPU_FRAMEBUFFER_WIDTH) / 8)

module gpu(input wire clk,
           input wire [3:0] gpu_cmd,
           input wire [11:0] gpu_draw_offset,
           input wire [7:0] gpu_draw_length,
           input wire [7:0] gpu_draw_x,
           input wire [7:0] gpu_draw_y,
           input wire gpu_cmd_submitted,
           output reg gpu_collision = 0,
           output wire gpu_ready,
           // Memory
           output reg gpu_mem_read = 0,
           output reg [11:0] gpu_mem_read_addr = 12'b0,
           input wire [7:0] gpu_mem_read_data,
           input wire gpu_mem_read_ack,
           output reg gpu_mem_write = 0,
           output reg [11:0] gpu_mem_write_addr = 12'b0,
           output reg [7:0] gpu_mem_write_data = 8'b0);

    localparam
        STATE_WAIT_FOR_CMD = 0,
        STATE_DECODE_CMD = 1, 
        STATE_CLEARING = 2,
        STATE_BEGIN_LINE_DRAW = 3,
        STATE_LOAD_SPRITE = 4,
        STATE_LOAD_FB_LEFT = 5,
        STATE_LOAD_FB_RIGHT = 6,
        STATE_STORE_FB_LEFT = 7,
        STATE_STORE_FB_RIGHT = 8;

    reg[7:0] state = STATE_WAIT_FOR_CMD;
    reg [11:0] clear_left;
    reg [7:0] lines_left;
    reg unaligned = 0;
    reg [7:0] shift;
    reg [15:0] current_line;

    // We are ready for a new command
    assign gpu_ready = state == STATE_WAIT_FOR_CMD;

    always @(posedge clk) begin
        gpu_mem_read <= 0;
        gpu_mem_write <= 0;

        case(state)
            // Idle
            STATE_WAIT_FOR_CMD: begin
                if (gpu_cmd_submitted) begin
                    state <= STATE_DECODE_CMD;
                end
            end
            // Decodes the commands and sets up registers for the operation
            STATE_DECODE_CMD: begin
                case(gpu_cmd)
                    `GPU_CMD_CLEAR: begin
                        clear_left <= `GPU_FRAMEBUFFER_LENGTH;
                        state <= STATE_CLEARING;
                    end
                    `GPU_CMD_DRAW: begin
                        gpu_collision <= 0;
                        lines_left <= gpu_draw_length;
                        // Setup registers for unaligned drawing
                        unaligned <= gpu_draw_x % 8 != 0;
                        shift <= gpu_draw_x % 8;
                        gpu_mem_read <= 1;
                        gpu_mem_read_addr <= gpu_draw_offset;
                        state <= STATE_BEGIN_LINE_DRAW;
                    end
                endcase
            end
            // Clears the framebuffer
            STATE_CLEARING: begin
                gpu_mem_write_addr <= `GPU_FRAMEBUFFER_OFFSET + clear_left;
                gpu_mem_write_data <= 0;
                clear_left <= clear_left - 1;
                if (clear_left == 0) begin
                    state <= STATE_WAIT_FOR_CMD;
                end
            end
            // Begin drawing the line
            STATE_BEGIN_LINE_DRAW: begin
                state <= STATE_LOAD_SPRITE;
            end
            STATE_LOAD_SPRITE: begin
                if (gpu_mem_read_ack) begin
                    current_line <= {gpu_mem_read_data, 8'b0} >> shift;

                    gpu_mem_read <= 1;
                    gpu_mem_read_addr <= `get_offset_for_fb(gpu_draw_x, gpu_draw_y);

                    state <= STATE_LOAD_FB_LEFT;
                end
            end
            // Load the current fb values and XOR it with the sprite and compute collision
            STATE_LOAD_FB_LEFT: begin
                if(gpu_mem_read_ack) begin
                    current_line[15:8] <= gpu_mem_read_data ^ current_line[15:8];
                    gpu_collision <= gpu_collision || (gpu_mem_read_data & current_line[15:8]);

                    if (unaligned) begin
                        gpu_mem_read <= 1;
                        gpu_mem_read_addr <= `get_offset_for_fb(gpu_draw_x + 1, gpu_draw_y);

                        state <= STATE_LOAD_FB_RIGHT;
                    end else begin
                        gpu_mem_write <= 1;
                        gpu_mem_write_addr <= `get_offset_for_fb(gpu_draw_x, gpu_draw_y);
                        gpu_mem_write_data <= current_line[15:8];

                        state <= STATE_STORE_FB_LEFT;
                    end
                end
            end
            STATE_LOAD_FB_RIGHT: begin
                if(gpu_mem_read_ack) begin
                    current_line[7:0] <= gpu_mem_read_data ^ current_line[7:0];
                    gpu_collision <= gpu_collision || (gpu_mem_read_data & current_line[7:0]);

                    gpu_mem_write <= 1;
                    gpu_mem_write_addr <= `get_offset_for_fb(gpu_draw_x, gpu_draw_y);
                    gpu_mem_write_data <= current_line[15:8];

                    state <= STATE_STORE_FB_LEFT;
                end
            end
            // Let the memory get written before returning
            STATE_STORE_FB_LEFT: begin
                if (unaligned) begin
                    gpu_mem_write <= 1;
                    gpu_mem_write_addr <= `get_offset_for_fb(gpu_draw_x + 1, gpu_draw_y);
                    gpu_mem_write_data <= current_line[15:8];

                    state <= STATE_STORE_FB_RIGHT;
                end else begin
                    state <= STATE_WAIT_FOR_CMD;
                end
            end
            STATE_STORE_FB_RIGHT: begin
                state <= STATE_WAIT_FOR_CMD;
            end
        endcase
    end

endmodule
