`include "cpu_bcd.v"
`include "cpu_rng.v"
`include "gpu_cmd.v"

module cpu(input wire clk,
           input wire timer_cpu_tick,
           input wire timer_60hz_tick,
           input wire gpu_ready,
           input wire [15:0] keypad_value,
           // Memory
           output reg mem_read = 0,
           output reg [11:0] mem_read_addr = 0,
           input wire [7:0] mem_read_data,
           input wire mem_read_ack,
           output reg mem_write = 0,
           output reg [11:0] mem_write_addr = 0,
           output reg [7:0] mem_write_data = 0,
           // GPU
           output reg [3:0] gpu_cmd = 0,
           output reg [11:0] gpu_draw_offset = 0,
           output reg [7:0] gpu_draw_x = 0,
           output reg [7:0] gpu_draw_y = 0,
           output reg [7:0] gpu_draw_length = 0,
           output reg gpu_cmd_submitted = 0,
           input wire gpu_collision);

    reg [15:0] pc = 'h200; // Program counter
    reg [7:0] regs[0:15]; // 16 8-bit registers (V0-VF)
    reg [15:0] reg_i = 0;
    reg [15:0] stack[0:31]; // 64 bytes stack (but is using 16-bit values internally to hold the pc's natively)

    reg [7:0] sp = 0; // Stack pointer
    reg [7:0] dt = 0; // Delay timer
    reg [7:0] st = 0; // Sound timer

    reg [15:0] instruction = 0; // Stores the current instruction
    wire [3:0] x = instruction[11:8]; // The X part of the instruction (2nd nibble)
    wire [3:0] y = instruction[7:4]; // The Y part of the instruciton (3rd nibble)
    wire [3:0] z = instruction[3:0]; // The Y part of the instruciton (3rd nibble)
    wire [7:0] kk = instruction[7:0]; // The kk part of the instruction (last two nibbles)
    wire [11:0] nnn = instruction[11:0]; // The nnn part of the instruction (last three nibbles)

    // Next vals
    reg [7:0] next_vx_reg = 0;
    reg next_carry = 0;
    reg [15:0] next_i_reg = 0;
    reg [7:0] next_sp = 0;

    // BCD
    reg [7:0] bcd_input = 0;
    wire [3:0] bcd_hundreds;
    wire [3:0] bcd_tens;
    wire [3:0] bcd_ones;

    // RNG
    wire [30:0] rng_value;

    // Memory store / read ops
    reg [7:0] memory_counter; // countdown from offset
    reg [3:0] memory_reg_end;

    localparam
        STATE_BEGIN = 0, // Alias to the first state of an cycle
        STATE_FETCH_INSTRUCTION_LO = 0, // Load the first byte of the current instruction
        STATE_FETCH_INSTRUCTION_HI = 1, // Load the last byte of the current instruction
        STATE_DECODE_INSTRUCTION = 2, // Decodes the instruction and changes the state accordenly
        STATE_WAIT_CLK = 3,
        STATE_STORE_CARRY_REG = 4,
        STATE_STORE_VX_REG = 5,
        STATE_STORE_I_REG = 6,
        STATE_STORE_SP_REG = 7,
        STATE_STORE_BCD1 = 8,
        STATE_STORE_BCD2 = 9,
        STATE_STORE_BCD3 = 10,
        STATE_STORE_MEMORY = 11,
        STATE_LOAD_MEMORY = 12,
        STATE_LOAD_MEMORY_STORE = 13,
        STATE_HALT_UNTIL_PRESS = 14,
        STATE_SUBMIT_GPU_CMD = 15,
        STATE_WAIT_FOR_GPU = 16,
        STATE_WAIT_CYCLE = 17;

    reg[7:0] state = STATE_WAIT_CLK;
    reg[7:0] wait_state = STATE_WAIT_CLK;

    // Initialize all the regs to 0
    integer i;
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            regs[i] = 0;
        end
    end

    always @(posedge clk) begin
        // Reset these
        mem_read <= 0;
        mem_write <= 0;

        if (timer_60hz_tick) begin
            if (dt != 0)
                dt <= dt - 1;

            if (st != 0)
                st <= st - 1;
        end

        case(state)
            // Loads the first byte of the instruction, takes approx two cycles
            STATE_FETCH_INSTRUCTION_LO: begin
                if (mem_read_ack) begin
                    // Load it into the instruction register
                    instruction[15:8] <= mem_read_data;

                    wait_state <= STATE_FETCH_INSTRUCTION_HI;
                    state <= STATE_WAIT_CYCLE;
                end else begin
                    mem_read_addr <= pc;
                    mem_read <= 1;
                end
            end

            // Loads the second byte of the instructions, takes approx two cycles
            STATE_FETCH_INSTRUCTION_HI: begin
                if (mem_read_ack) begin
                    // Load it into the instruction register
                    instruction[7:0] <= mem_read_data;

                    wait_state <= STATE_DECODE_INSTRUCTION;
                    state <= STATE_WAIT_CYCLE;
                end else begin
                    mem_read_addr <= pc + 1;
                    mem_read <= 1;
                end
            end

            // Wait until the instruction has been read and then evaluate
            STATE_DECODE_INSTRUCTION: begin
                state <= STATE_WAIT_CLK;
                pc <= pc + 2;

                $write("%h - ", pc);

                casez(instruction)
                    // CLS - 00E0 - Clear the display
                    16'h00E0: begin
                        $display("CLS");

                        gpu_cmd <= `GPU_CMD_CLEAR;
                        gpu_cmd_submitted <= 1;
                        state <= STATE_SUBMIT_GPU_CMD;
                    end

                    // RET - 00EE
                    // Return from subrutine and pop the top value of the stack and set the program counter to it
                    16'h00EE: begin
                        $display("RET - PC = %h", stack[sp - 1]);

                        pc <= stack[sp - 1] + 2;
                        next_sp <= sp - 1;
                        state <= STATE_STORE_SP_REG;
                    end

                    // JP addr - 1nnn
                    // Jump / set program counter to nnn
                    16'h1???: begin
                        $display("JP addr - PC = %h", nnn);

                        pc <= nnn;
                    end

                    // CALL addr - 2nnn
                    // Puts the current pc value on top of the stack and jumps to the addr
                    16'h2???: begin
                        $display("CALL addr - %h", nnn);

                        stack[sp] <= pc;
                        next_sp <= sp + 1;
                        pc <= nnn;
                        state <= STATE_STORE_SP_REG;
                    end

                    // SE Vx, byte - 3xkk
                    // Skips the next instruction if Vx equals kk
                    16'h3???: begin
                        $display("SE Vx, byte - V%0h (%h) == %h", x, regs[x], kk);

                        if (regs[x] == kk)
                            pc <= pc + 4;
                    end

                    // SNE Vx, byte - 4xkk
                    // Skips the next instruction if Vx is not equal kk
                    16'h4???: begin
                        $display("SNE Vx, byte - V%0h (%h) != %h", x, regs[x], kk);

                        if (regs[x] != kk)
                            pc <= pc + 4;
                    end

                    // SE Vx, Vy - 5xy0
                    // Skips the next instruction if Vx equals Vy
                    16'h5??0: begin
                        $display("SE Vx, Vy - V%0h (%h) == %h", x, regs[x], regs[y]);

                        if (regs[x] == regs[y])
                            pc <= pc + 4;
                    end

                    // LD Vx, byte - 6xkk
                    // Vx = kk
                    // Sets register Vx's value to kk
                    16'h6???: begin
                        $display("LD Vx, byte - V%0h = %h", x, kk);

                        next_vx_reg <= kk;
                        state <= STATE_STORE_VX_REG;
                    end

                    // ADD Vx, byte - 7xkk
                    // Vx = Vx + kk
                    // Sets register Vx's value to Vx + kk
                    16'h7???: begin
                        $display("ADD Vx, Vy - V%0h (%h) = V%0h (%h) + %h", x, regs[x] + kk, x, regs[x], kk);

                        next_vx_reg <= regs[x] + kk;
                        state <= STATE_STORE_VX_REG;
                    end

                    // LD Vx, Vy - 8xy0
                    // Vx = Vy
                    // Sets register Vx's value to Vy
                    16'h8??0: begin
                        $display("LD Vx, Vy - V%0h = V%0h (%h)", x, y, regs[y]);

                        next_vx_reg <= regs[y];
                        state <= STATE_STORE_VX_REG;
                    end

                    // OR Vx, Vy - 8xy1
                    // Vx = Vx OR Vy
                    // Performes bitwise OR on Vx and Vy and stores in in Vx
                    16'h8??1: begin
                        $display("OR Vx, Vy - V%0h (%h) = V%0h (%h) OR V%0h (%h)", x, regs[x] | regs[y], x, regs[x], y, regs[y]);

                        next_vx_reg <= regs[x] | regs[y];
                        state <= STATE_STORE_VX_REG;
                    end

                    // AND Vx, Vy - 8xy2
                    // Vx = Vx AND Vy
                    // Performes bitwise AND on Vx and Vy and stores in in Vx
                    16'h8??2: begin
                        $display("AND Vx, Vy - V%0h (%h) = V%0h (%h) AND V%0h (%h)", x, regs[x] & regs[y], x, regs[x], y, regs[y]);

                        next_vx_reg <= regs[x] & regs[y];
                        state <= STATE_STORE_VX_REG;
                    end

                    // XOR Vx, Vy - 8xy3
                    // Vx = Vx XOR Vy
                    // Performes bitwise XOR on Vx and Vy and stores in Vx
                    16'h8??3: begin
                        $display("XOR Vx, Vy - V%0h (%h) = V%0h (%h) XOR V%0h (%h)", x, regs[x] ^ regs[y], x, regs[x], y, regs[y]);

                        next_vx_reg <= regs[x] ^ regs[y];
                        state <= STATE_STORE_VX_REG;
                    end

                    // ADD Vx, Vy - 8xy4
                    // Vx = Vx + Vy, VF = carry
                    // Adding up Vx and Vy and stores the result in Vx, sets VF to 1 on overflow otherwise 0
                    16'h8??4: begin
                        $display("ADD Vx, Vy - V%0h (%h) = V%0h (%h) + V%0h (%h)", x, regs[x] + regs[y], x, regs[x], y, regs[y]);

                        next_vx_reg <= regs[x] + regs[y];
                        // If it has overflown set the carry bit to 1
                        next_carry <= ((regs[x] + regs[y]) >= 256) ? 1 : 0;
                        state <= STATE_STORE_CARRY_REG;
                    end

                    // SUB Vx, Vy - 8xy5
                    // Vx = Vx - Vy, VF = NOT borrow
                    // Subtracts Vy from Vx and stores the result in in Vx, sets VF to 1 on underflow otherwise 0
                    16'h8??5: begin
                        $display("SUB Vx, Vy - V%0h (%h) = V%0h (%h) - V%0h (%h)", x, regs[x] - regs[y], x, regs[x], y, regs[y]);

                        next_vx_reg <= regs[x] - regs[y];
                        // If it has underflowed set the carry bit to 1
                        next_carry <= (regs[x] > regs[y]) ? 1 : 0;
                        state <= STATE_STORE_CARRY_REG;
                    end

                    // SHR Vx {, Vy} - 8xy6
                    // Vx = Vx SHR 1
                    // Sets Vx to Vy shifted right by 1, if the LSB of Vx is 1 then VF is set to 1 otherwise 0.
                    16'h8??6: begin
                        $display("SHR Vx >> 1 - V%0h (%h) = V%0h (%h) >> 1", x, regs[x] >> 1, x, regs[x]);

                        next_vx_reg <= regs[x] >> 1;
                        // Set the carry to the LSB of the Vx
                        next_carry <= regs[x][0:0];
                        state <= STATE_STORE_CARRY_REG;
                    end

                    // SUBN Vx, Vy - 8xy7
                    // Vx = Vy - Vx, set VF = NOT borrow
                    // Subtracts Vx from Vy and stores the result in in Vx, sets VF to 1 on underflow otherwise 0
                    16'h8??7: begin
                        $display("SUBN Vx, Vy - V%0h (%h) = V%0h (%h) - V%0h (%h)", x, regs[y] - regs[x], y, regs[y], x, regs[x]);

                        next_vx_reg <= regs[y] - regs[x];
                        // If it has underflowed set the carry bit to 1
                        next_carry <= (regs[y] > regs[x]) ? 1 : 0;
                        state <= STATE_STORE_CARRY_REG;
                    end

                    // SHL Vx {, Vy} - 8xy8
                    // Vx = Vx SHL 1
                    // Sets Vx to Vy shifted left by 1, if the MSB of Vx is 1 then VF is set to 1 otherwise 0.
                    16'h8??8: begin
                        $display("SHR Vx << 1 - V%0h (%h) = V%0h (%h) << 1", x, regs[x] << 1, x, regs[x]);

                        next_vx_reg <= regs[x] << 1;
                        // Set the carry to the LSB of the Vx
                        next_carry <= regs[x][7:7];
                        state <= STATE_STORE_CARRY_REG;
                    end

                    // SNE Vx, Vy - 9xy0
                    // Skips the next instruction if Vx does not equal Vy
                    16'h9??0: begin
                        $display("SNE Vx, Vy - V%0h (%h) != V%0h (%h)", x, regs[x], y, regs[y]);

                        if (regs[x] != regs[y])
                            pc <= pc + 4;
                    end

                    // LD I, addr - Annn
                    // Sets the value of register I to nnn
                    16'hA???: begin
                        $display("LD I, addr - I = %h", nnn);

                        next_i_reg <= nnn;
                        state <= STATE_STORE_I_REG;
                    end

                    // JP V0, addr - Bnnn
                    // Sets the program counter to V0 + nnn
                    16'hB???: begin
                        $display("JP V0, addr - PC = V0 (%h) + %h", regs[0], nnn);

                        pc <= regs[0] + nnn;
                    end

                    // RND Vx, byte - Cxkk
                    // Vx = (RANDOM BYTE) AND kk
                    // Sets Vx to a random byte bitwise AND'd to kk
                    16'hC???: begin
                        $display("RNG Vx, byte - V%0h (%h) = %h & %h", x, rng_value[7:0] & kk, rng_value[7:0], kk);

                        next_vx_reg <= rng_value[7:0] & kk;
                        state <= STATE_STORE_VX_REG;
                    end

                    // DRW Vx, Vy, nibble - Dxyn
                    // Draws a n byte long sprite located at the I reg memory location at (Vx, Xy). Pixels are copied XOR to detect collisions, if
                    // something collides set VF to 1 otherwise 0. If pixels are outside of the framebuffer will it wrap over to the other side
                    16'hD???: begin
                        $display("DRW Vx, Vy, nibble - V%0h (%h), V%0h (%h), %0d", x, regs[x], y, regs[y], z);

                        gpu_cmd <= `GPU_CMD_DRAW;
                        gpu_draw_x <= regs[x];
                        gpu_draw_y <= regs[y];
                        gpu_draw_offset <= reg_i;
                        gpu_draw_length <= z;
                        gpu_cmd_submitted <= 1;
                        state <= STATE_SUBMIT_GPU_CMD;
                    end

                    // SKP Vx - Ex9E
                    // Skips the next instruction if the key of register Vx's value is currently down
                    16'hE?9E: begin
                        $display("SKP Vx - V%0h (%0d), down: %0d", x, regs[x], keypad_value & (1 << (regs[x] - 1)));

                        if (keypad_value & (1 << (regs[x] - 1)))
                            pc <= pc + 4;
                    end

                    // SKNP Vx - ExA1
                    // Skips the next instruction if the key of register Vx's value is currently up
                    16'hE?A1: begin
                        $display("SKNP Vx - V%0h (%0d), down: %0d", x, regs[x], keypad_value & (1 << (regs[x] - 1)));

                        if (!(keypad_value & (1 << (regs[x] - 1))))
                            pc <= pc + 4;
                    end

                    // LD Vx, DT - Fx07
                    // Sets Vx to the Delay Timer's value
                    16'hF?07: begin
                        $display("LD Vx, DT - V%0h = DT (%h)", x, dt);

                        next_vx_reg <= dt;
                        state <= STATE_STORE_VX_REG;
                    end

                    // LD Vx, K - Fx0A
                    // Halts all execution until a key is pressed and stores it in Vx
                    16'hF?0A: begin
                        $display("LD Vx, K");

                        state <= STATE_HALT_UNTIL_PRESS;
                    end

                    // LD DT, Vx - Fx15
                    // Sets the Delay Timer to Vx
                    16'hF?15: begin
                        $display("LD DT, Vx - DT = V%0h (%h)", x, regs[x]);

                        dt <= regs[x];
                    end

                    // LD ST, Vx - Fx18
                    // Sets the Sound Timer to Vx
                    16'hF?18: begin
                        $display("LD ST, Vx - ST = V%0h (%h)", x, regs[x]);

                        st <= regs[x];
                    end

                    // ADD I, Vx - Fx1E
                    // I = I + Vx
                    // I is set to I + Vx
                    16'hF?1E: begin
                        $display("ADD I, Vx - I (%h) = I (%h) + V%0h (%h)", reg_i + regs[x], reg_i, x, regs[x]);

                        next_i_reg <= reg_i + regs[x];
                        state <= STATE_STORE_I_REG;
                    end

                    // LD F, Vx - Fx29
                    // Sets register I to the location of sprite digit Vx.
                    16'hF?29: begin
                        $display("LD F, Vx - I (%h) = V%0h (%h) * 5", regs[x] * 5, x, regs[x]);

                        next_i_reg <= regs[x] * 5;
                        state <= STATE_STORE_I_REG;
                    end

                    // LD B, Vx - Fx33
                    // Stores the binary coded decimal value of Vx in I, I + 1 and I + 2
                    16'hF?33: begin
                        $display("LD B, Vx - I, I + 1, I + 2 = BCD(V%0h (%h))", x, regs[x]);
                        bcd_input <= regs[x];
                        state <= STATE_STORE_BCD1;
                    end

                    // LD [I], Vx - Fx55
                    // Stores V0 to Vx starting at reg I's value, I is then set to I + x + 1
                    16'hF?55: begin
                        $display("LD [I], I..I + %0d Vx - V0..V%0h, I = I + %0d + 1", x, x, x);
                        memory_counter = x;
                        next_i_reg = reg_i + x + 1;
                        state <= STATE_STORE_MEMORY;
                    end

                    // LD Vx, [I] - Fx65
                    // Filles V0 to Vx with memory stored at reg I's value, I is then set to I + x + 1
                    16'hF?65: begin
                        $display("LD [I], V0..V%0h = I..I + %0d, I = I + %0d + 1", x, x, x);
                        memory_counter = x;
                        next_i_reg = reg_i + x + 1;
                        state <= STATE_LOAD_MEMORY;
                    end
                endcase
            end

            // Do nothing until the next cpu 500hz cycle tick
            STATE_WAIT_CLK: begin
                // Start a new state cycle
                if (timer_cpu_tick) begin
                    memory_counter = 0;
                    state <= STATE_BEGIN;
                end
            end

            // Store the carry to VF
            STATE_STORE_CARRY_REG: begin
                regs['hf] = next_carry;
                state <= STATE_STORE_VX_REG;
            end

            // Store the Vx reg
            STATE_STORE_VX_REG: begin
                regs[x] = next_vx_reg;
                state <= STATE_WAIT_CLK;
            end

            STATE_STORE_I_REG: begin
                reg_i = next_i_reg;
                state <= STATE_WAIT_CLK;
            end

            // Store the stack pointer
            STATE_STORE_SP_REG: begin
                sp <= next_sp;
                state <= STATE_WAIT_CLK;
            end

            STATE_STORE_BCD1: begin
                mem_write <= 1;
                mem_write_addr <= reg_i;
                mem_write_data <= bcd_hundreds;
                state <= STATE_STORE_BCD2;
            end

            STATE_STORE_BCD2: begin
                mem_write <= 1;
                mem_write_addr <= reg_i + 1;
                mem_write_data <= bcd_tens;
                state <= STATE_STORE_BCD3;
            end

            STATE_STORE_BCD3: begin
                mem_write <= 1;
                mem_write_addr <= reg_i + 2;
                mem_write_data <= bcd_ones;
                state <= STATE_WAIT_CLK;
            end

            STATE_STORE_MEMORY: begin
                mem_write <= 1;
                mem_write_addr <= reg_i + memory_counter;
                mem_write_data <= regs[memory_counter];
                memory_counter <= memory_counter - 1;

                if (memory_counter == 0) begin
                    state <= STATE_STORE_I_REG;
                end
            end
            STATE_LOAD_MEMORY: begin
                mem_read <= 1;
                mem_read_addr <= reg_i + memory_counter;

                state <= STATE_LOAD_MEMORY_STORE;
            end
            STATE_LOAD_MEMORY_STORE: begin
                if (mem_read_ack) begin
                    regs[memory_counter] = mem_read_data;

                    if (memory_counter == 0) begin
                        state <= STATE_STORE_I_REG;
                    end else begin
                        memory_counter <= memory_counter - 1;

                        state <= STATE_LOAD_MEMORY;
                    end
                end
            end
            STATE_HALT_UNTIL_PRESS: begin
                if (keypad_value & (1 << (regs[x] - 1)))
                    state <= STATE_WAIT_CLK;
            end

            STATE_SUBMIT_GPU_CMD: begin
                state <= STATE_WAIT_FOR_GPU;
            end

            STATE_WAIT_FOR_GPU: begin
                gpu_cmd_submitted <= 0;
                if (gpu_ready) begin
                    state <= STATE_WAIT_CLK;
                    regs['hf] = gpu_collision;
                end
            end

            STATE_WAIT_CYCLE: begin
                state <= wait_state;
            end
        endcase
    end

    // BCD module
    cpu_bcd bcd(.binary(bcd_input),
    .hundreds(bcd_hundreds),
    .tens(bcd_tens),
    .ones(bcd_ones));

    // RNG module
    cpu_rng rng(.clk(clk),
    .value(rng_value));
endmodule
