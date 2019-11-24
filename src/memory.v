module memory(input wire clk,
              input wire read,
              input wire [11:0] read_addr,
              output reg [7:0] read_data = 0,
              input wire write,
              input wire [11:0] write_addr,
              input wire [7:0] write_data);

    parameter MEMORY_SIZE = 4096;

    reg [7:0] mem[0:MEMORY_SIZE - 1];

    // Zero out the memory
    integer i;
    initial begin
        for (i = 0; i < MEMORY_SIZE - 1; i = i + 1) begin
            mem[i] = 0;
        end
    end

    always @(posedge clk) begin
        // Read memory
        if (read) begin
            read_data <= mem[read_addr];
        end
        // Write memory
        if (write) begin
            mem[write_addr] <= write_data;
        end
    end
endmodule
