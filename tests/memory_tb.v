`include "memory.v"

`include "utils.v"

module memory_tb;
    reg clk = 0;

    reg mem_read = 0;
    reg [11:0] mem_read_addr;
    wire [7:0] mem_read_data;
    reg mem_write = 0;
    reg [11:0] mem_write_addr;
    reg [7:0] mem_write_data;

    memory memory(.clk(clk),
    .read(mem_read),
    .read_addr(mem_read_addr),
    .read_data(mem_read_data),
    .write(mem_write),
    .write_addr(mem_write_addr),
    .write_data(mem_write_data));

    initial
        forever #1 clk = ~clk;

    integer i;
    initial begin
        $dumpfile(`VCD_PATH);
        $dumpvars;

        // Read offset 0
        mem_read <= 1;
        mem_read_addr <= 0;
        #2 `assert_eq(mem_read_data, 0);
        mem_read <= 0;

        // Write 1-255 on 1-255 addr
        for (i = 0; i < 255; i++) begin
            mem_write <= 1;
            mem_write_addr <= i;
            mem_write_data <= i;
            #2;
            mem_write <= 0;
            #2;
        end

        // Read 1-255 on 1-255 addr
        for (i = 0; i < 255; i++) begin
            mem_read <= 1;
            mem_read_addr <= i;
            #2 `assert_eq(mem_read_data, i);
            mem_read <= 0;
            #2;
        end

        $finish;
    end
endmodule
