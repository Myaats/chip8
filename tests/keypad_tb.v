`include "keypad.v"

`include "utils.v"

module keypad_tb;
    reg clk = 0;

    wire [3:0] keypad_column;
    reg [3:0] keypad_row = 0;
    wire [15:0] keypad_value;

    keypad keypad(.clk(clk),
    .column(keypad_column),
    .row(keypad_row),
    .value(keypad_value));

    initial
        forever #1 clk = ~clk;

    integer row = 0;
    integer column = 0;
    initial begin
        $dumpfile(`VCD_PATH);
        $dumpvars;

        for (row = 0; row < 4; row++) begin
            for (column = 0; column < 4; column++) begin
                keypad_row <= ~('b1000 >> row);
                #1;
                // Check if the correct column is high
                `assert_eq(keypad_column, 'b1000 >> column);
                #1;
                // check if the right keypad value bit is set
                if (column == 0)
                    `assert_eq(keypad_value[15:12], ('b1000 >> row));
                if (column == 1)
                    `assert_eq(keypad_value[11:8], ('b1000 >> row));
                if (column == 3)
                    `assert_eq(keypad_value[7:4], ('b1000 >> row));
                if (column == 4)
                    `assert_eq(keypad_value[3:0], ('b1000 >> row));
            end
        end

        keypad_row <= 'b1111;

        #32
        `assert_eq(keypad_value, 0);

        $finish;
    end
endmodule
