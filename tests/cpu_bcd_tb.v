`include "cpu_bcd.v"

`include "utils.v"

module timer_tb;
    reg [7:0] bcd_input = 0;
    wire [3:0] bcd_hundreds;
    wire [3:0] bcd_tens;
    wire [3:0] bcd_ones;

    initial begin
        $dumpfile(`VCD_PATH);
        $dumpvars;

        // Test #1 - 100
        bcd_input = 100;
        #1
        `assert_eq(bcd_hundreds, 1);
        `assert_eq(bcd_tens, 0);
        `assert_eq(bcd_ones, 0);
        // Test #2 - 255
        bcd_input = 255;
        #1
        `assert_eq(bcd_hundreds, 2);
        `assert_eq(bcd_tens, 5);
        `assert_eq(bcd_ones, 5);
        // Test #3 - 99
        bcd_input = 99;
        #1
        `assert_eq(bcd_hundreds, 0);
        `assert_eq(bcd_tens, 9);
        `assert_eq(bcd_ones, 9);

        $finish;
    end

    cpu_bcd bcd(.binary(bcd_input),
    .hundreds(bcd_hundreds),
    .tens(bcd_tens),
    .ones(bcd_ones));
endmodule
