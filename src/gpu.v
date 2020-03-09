`include "gpu_cmd.v"

`define GPU_FRAMEBUFFER_OFFSET 'h100
`define GPU_FRAMEBUFFER_LENGTH 'hFF

module gpu(input wire clk,
           input wire [3:0] gpu_cmd,
           input wire [15:0] gpu_draw_offset,
           input wire [7:0] gpu_draw_length,
           input wire [7:0] gpu_draw_x,
           input wire [7:0] gpu_draw_y,
           input wire gpu_cmd_submitted,
           output reg gpu_collision = 0,
           output wire gpu_ready = 1,
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
        STATE_DRAWING = 3;

    reg[7:0] state = STATE_WAIT_FOR_CMD;
    reg [11:0] clear_left;

    // We are ready for a new command
    assign gpu_ready = state == STATE_WAIT_FOR_CMD;

    always @(posedge clk) begin
        case(state)
            STATE_WAIT_FOR_CMD: begin
                if (gpu_cmd_submitted) begin
                    state <= STATE_DECODE_CMD;
                end
            end
            STATE_DECODE_CMD: begin
                case(gpu_cmd)
                    `GPU_CMD_CLEAR: begin
                        clear_left <= `GPU_FRAMEBUFFER_LENGTH;
                        state <= STATE_CLEARING;
                    end
                    `GPU_CMD_DRAW: begin
                        state <= STATE_DRAWING;
                    end
                endcase
            end
            STATE_CLEARING: begin
                gpu_mem_write_addr <= `GPU_FRAMEBUFFER_OFFSET + clear_left;
                gpu_mem_write_data <= 0;
                if (clear_left == 0) begin
                    state <= STATE_WAIT_FOR_CMD;
                end
            end
            STATE_DRAWING: begin

            end
        endcase
    end

endmodule
