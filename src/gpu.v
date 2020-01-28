module gpu(input wire clk,
           input wire [15:0] gpu_cmd,
           input wire gpu_cmd_submitted,
           output wire gpu_ready);

    localparam
        STATE_WAIT_FOR_CMD = 0,
        STATE_DECODE_CMD = 1, 
        STATE_CLEARING = 2;

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

            end
            STATE_CLEARING: begin

            end
        endcase
    end

endmodule
