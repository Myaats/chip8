`include "gpu_cmd.v"

`define GPU_FRAMEBUFFER_OFFSET 'h100
`define GPU_FRAMEBUFFER_LENGTH 'hFF

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
        STATE_DRAW_FB_LEFT = 7,
        STATE_DRAW_FB_RIGHT = 8;

    reg[7:0] state = STATE_WAIT_FOR_CMD;
    reg [11:0] clear_left;
    reg [7:0] lines_left;
    reg unaligned = 0;
    reg [7:0] shift;

    // We are ready for a new command
    assign gpu_ready = state == STATE_WAIT_FOR_CMD;

    always @(posedge clk) begin
        case(state)
            // Idle
            STATE_WAIT_FOR_CMD: begin
                gpu_mem_read <= 0;

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
                if(gpu_mem_read_ack) begin
                    
                end
            end
        endcase
    end

endmodule
