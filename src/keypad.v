module keypad(input wire clk,
              output reg [3:0] column = FIRST_COLUMN,
              input wire [3:0] row,
              output reg [15:0] value = 0);

    reg [1:0] current_column = 2'b00;

    parameter FIRST_COLUMN = 'b1000;

    integer i;
    always @(posedge clk) begin
        for (i = 0; i < 4; i = i + 1) begin
            value[i + 4 * (3 - current_column)] <= row[i] == 0;
        end

        column <= FIRST_COLUMN >> (current_column + 1) % 4;
        current_column <= current_column + 1;
    end
endmodule
