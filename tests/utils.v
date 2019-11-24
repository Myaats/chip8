`define assert_eq(a, b) \
    if (a !== b) begin \
        $display("ASSERTION FAILED in %m: a: ", a, " != b"); \
        $finish_and_return(1); \
    end
