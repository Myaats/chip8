`include "gpu_cmd.v"

module gpu(input wire clk,
           input wire [3:0] gpu_cmd,
           input wire [15:0] gpu_draw_offset,
           input wire [7:0] gpu_draw_x,
           input wire [7:0] gpu_draw_y,
           input wire [7:0] gpu_draw_length,
           input wire gpu_cmd_submitted,
           output reg gpu_collision,
           output wire gpu_ready);

    localparam
        STATE_WAIT_FOR_CMD = 0,
        STATE_DECODE_CMD = 1, 
        STATE_CLEARING = 2,
        STATE_DRAWING = 3;

    reg[7:0] state = STATE_WAIT_FOR_CMD;

    // We are ready for a new command
    assign gpu_ready  = state == STATE_WAIT_FOR_CMD;

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
                        state <= STATE_DECODE_CMD;
                    end
                    `GPU_CMD_DRAW: begin
                        state <= STATE_DRAWING;
                    end
                endcase
            end
            STATE_CLEARING: begin

            end
            STATE_DRAWING: begin

            end
        endcase
    end

endmodule
