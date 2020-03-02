module keypad(input wire clk,
              output reg [3:0] column,
              input wire [3:0] row,
              output reg [15:0] value);

    reg [1:0] current_column = 2'b00;

    integer i;
    initial begin
        value = 0;
    end

    always @(posedge clk) begin
        for (i = 0; i <= 3; i = i + 1) begin
            value[i * 4 + current_column] <= row[i] == 1;
        end

        current_column <= (current_column + 1) % 3;
        column <= 0;
        column[current_column] <= 1;
    end
endmodule
