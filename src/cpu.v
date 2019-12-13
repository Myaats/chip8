module cpu(input wire clk,
           input wire timer_cpu_tick,
           input wire timer_60hz_tick,
           // Memory
           output reg mem_read = 0,
           output reg [11:0] mem_read_addr = 0,
           input wire [7:0] mem_read_data,
           input wire mem_read_ack,
           output reg mem_write = 0,
           output reg [11:0] mem_write_addr = 0,
           output reg [7:0] mem_write_data = 0);

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
    wire [7:0] kk = instruction[7:0]; // The kk part of the instruction (last two nibbles)
    wire [11:0] nnn = instruction[11:0]; // The nnn part of the instruction (last three nibbles)

    // Next vals
    reg [7:0] next_vx_reg;
    reg next_carry;
    reg [15:0] next_i_reg;
    reg [7:0] next_sp;

    localparam
        STATE_BEGIN = 0, // Alias to the first state of an cycle
        STATE_FETCH_INSTRUCTION_LO = 0, // Load the first byte of the current instruction
        STATE_FETCH_INSTRUCTION_HI = 1, // Load the last byte of the current instruction
        STATE_DECODE_INSTRUCTION = 2, // Decodes the instruction and changes the state accordenly
        STATE_WAIT_CLK = 3,
        STATE_STORE_CARRY_REG = 4,
        STATE_STORE_VX_REG = 5,
        STATE_STORE_I_REG = 6,
        STATE_STORE_SP_REG = 7;

    reg[7:0] state = STATE_FETCH_INSTRUCTION_LO;

    // Initialize all the regs to 0
    integer i;
    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            regs[i] = 0;
        end
    end

    always @(posedge clk) begin
        case(state)
            // Loads the first byte of the instruction, takes approx two cycles
            STATE_FETCH_INSTRUCTION_LO: begin
                if (mem_read_ack) begin
                    mem_read <= 0;
                    state <= STATE_FETCH_INSTRUCTION_HI;
                    // Load it into the instruction register
                    instruction[15:8] = mem_read_data;
                end else begin
                    mem_read_addr <= pc;
                    mem_read <= 1;
                end
            end

            // Loads the second byte of the instructions, takes approx two cycles
            STATE_FETCH_INSTRUCTION_HI: begin
                if (mem_read_ack) begin
                    state <= STATE_DECODE_INSTRUCTION;
                    // Load it into the instruction register
                    instruction[7:0] = mem_read_data;
                end else begin
                    mem_read_addr <= pc + 1;
                    mem_read <= 1;
                end
            end

            // Wait until the instruction has been read and then evaluate
            STATE_DECODE_INSTRUCTION: begin
                state <= STATE_WAIT_CLK;
                pc <= pc + 2;

                casez(instruction)
                    // CLS - 00E0 - Clear the display
                    16'h00E0: begin

                    end

                    // RET - 00EE
                    // Return from subrutine and pop the top value of the stack and set the program counter to it
                    16'h00EE: begin
                        pc <= stack[sp - 1];
                        next_sp <= sp - 1;
                        state <= STATE_STORE_SP_REG;
                    end

                    // JP addr - 1nnn
                    // Jump / set program counter to nnn
                    16'h1???: begin
                        pc <= nnn;
                    end

                    // CALL addr - 2nnn
                    // Puts the current pc value on top of the stack and jumps to the addr
                    16'h2???: begin
                        stack[sp] <= pc;
                        next_sp <= sp + 1;
                        pc <= nnn;
                        state <= STATE_STORE_SP_REG;
                    end

                    // SE Vx, byte - 3xkk
                    // Skips the next instruction if Vx equals kk
                    16'h3???: begin
                        if (regs[x] == kk)
                            pc <= pc + 2;
                    end

                    // SNE Vx, byte - 4xkk
                    // Skips the next instruction if Vx is not equal kk
                    16'h4???: begin
                        if (regs[x] != kk)
                            pc <= pc + 2;
                    end

                    // SE Vx, Vy - 5xy0
                    // Skips the next instruction if Vx equals Vy
                    16'h5??0: begin
                        if (regs[x] == regs[y])
                            pc <= pc + 2;
                    end

                    // LD Vx, byte - 6xkk
                    // Vx = kk
                    // Sets register Vx's value to kk
                    16'h6???: begin
                        next_vx_reg <= kk;
                        state <= STATE_STORE_VX_REG;
                    end

                    // ADD Vx, byte - 7xkk
                    // Vx = Vx + kk
                    // Sets register Vx's value to Vx + kk
                    16'h7???: begin
                        next_vx_reg <= regs[x] + kk;
                        state <= STATE_STORE_VX_REG;
                    end

                    // LD Vx, Vy - 8xy0
                    // Vx = Vy
                    // Sets register Vx's value to Vy
                    16'h8??0: begin
                        next_vx_reg <= regs[y];
                        state <= STATE_STORE_VX_REG;
                    end

                    // OR Vx, Vy - 8xy1
                    // Vx = Vx OR Vy
                    // Performes bitwise OR on Vx and Vy and stores in in Vx
                    16'h8??1: begin
                        next_vx_reg <= regs[x] | regs[y];
                        state <= STATE_STORE_VX_REG;
                    end

                    // AND Vx, Vy - 8xy2
                    // Vx = Vx AND Vy
                    // Performes bitwise AND on Vx and Vy and stores in in Vx
                    16'h8??2: begin
                        next_vx_reg <= regs[x] & regs[y];
                        state <= STATE_STORE_VX_REG;
                    end

                    // XOR Vx, Vy - 8xy3
                    // Vx = Vx XOR Vy
                    // Performes bitwise XOR on Vx and Vy and stores in Vx
                    16'h8??3: begin
                        next_vx_reg <= regs[x] ^ regs[y];
                        state <= STATE_STORE_VX_REG;
                    end

                    // ADD Vx, Vy - 8xy4
                    // Vx = Vx + Vy, VF = carry
                    // Adding up Vx and Vy and stores the result in Vx, sets VF to 1 on overflow otherwise 0
                    16'h8??4: begin
                        next_vx_reg <= regs[x] + regs[y];
                        // If it has overflown set the carry bit to 1
                        next_carry <= ((regs[x] + regs[y]) >= 256) ? 1 : 0;
                        state <= STATE_STORE_CARRY_REG;
                    end

                    // SUB Vx, Vy - 8xy5
                    // Vx = Vx - Vy, VF = NOT borrow
                    // Subtracts Vy from Vx and stores the result in in Vx, sets VF to 1 on underflow otherwise 0
                    16'h8??5: begin
                        next_vx_reg <= regs[x] - regs[y];
                        // If it has underflowed set the carry bit to 1
                        next_carry <= (regs[x] > regs[y]) ? 1 : 0;
                        state <= STATE_STORE_CARRY_REG;
                    end

                    // SHR Vx {, Vy} - 8xy6
                    // Vx = Vx SHR 1
                    // Sets Vx to Vy shifted right by 1, if the LSB of Vx is 1 then VF is set to 1 otherwise 0.
                    16'h8??6: begin
                        next_vx_reg <= regs[x] >> 1;
                        // Set the carry to the LSB of the Vx
                        next_carry <= regs[x][0:0];
                        state <= STATE_STORE_CARRY_REG;
                    end

                    // SUBN Vx, Vy - 8xy7
                    // Vx = Vy - Vx, set VF = NOT borrow
                    // Subtracts Vx from Vy and stores the result in in Vx, sets VF to 1 on underflow otherwise 0
                    16'h8??7: begin
                        next_vx_reg <= regs[y] - regs[x];
                        // If it has underflowed set the carry bit to 1
                        next_carry <= (regs[y] > regs[x]) ? 1 : 0;
                        state <= STATE_STORE_CARRY_REG;
                    end

                    // SHL Vx {, Vy} - 8xy8
                    // Vx = Vx SHL 1
                    // Sets Vx to Vy shifted left by 1, if the MSB of Vx is 1 then VF is set to 1 otherwise 0.
                    16'h8??8: begin
                        next_vx_reg <= regs[x] << 1;
                        // Set the carry to the LSB of the Vx
                        next_carry <= regs[x][7:7];
                        state <= STATE_STORE_CARRY_REG;
                    end

                    // SNE Vx, Vy - 9xy0
                    // Skips the next instruction if Vx does not equal Vy
                    16'h9??0: begin
                        if (regs[x] != regs[y])
                            pc <= pc + 2;
                    end

                    // LD I, addr - Annn
                    // Sets the value of register I to nnn
                    16'hA???: begin
                        next_i_reg <= nnn;
                        state <= STATE_STORE_I_REG;
                    end

                    // JP V0, addr - Bnnn
                    // Sets the program counter to V0 + nnn
                    16'hB???: begin
                        pc <= regs[0] + nnn;
                    end

                    // RND Vx, byte - Cxkk
                    // Vx = (RANDOM BYTE) AND kk
                    // Sets Vx to a random byte bitwise AND'd to kk
                    16'hC???: begin

                    end

                    // DRW Vx, Vy, nibble - Dxyn
                    // Draws a n byte long sprite located at the I reg memory location at (Vx, Xy). Pixels are copied XOR to detect collisions, if
                    // something collides set VF to 1 otherwise 0. If pixels are outside of the framebuffer will it wrap over to the other side
                    16'hD???: begin

                    end

                    // SKP Vx - Ex9E
                    // Skips the next instruction if the key of register Vx's value is currently down
                    16'hE?9E: begin

                    end

                    // SKNP Vx - ExA1
                    // Skips the next instruction if the key of register Vx's value is currently up
                    16'hE?A1: begin

                    end

                    // LD Vx, DT - Fx07
                    // Sets Vx to the Delay Timer's value
                    16'hF?07: begin
                        next_vx_reg <= dt;
                        state <= STATE_STORE_VX_REG;
                    end

                    // LD Vx, K - Fx0A
                    // Halts all execution until a key is pressed and stores it in Vx
                    16'hF?0A: begin

                    end

                    // LD DT, Vx - Fx15
                    // Sets the Delay Timer to Vx
                    16'hF?15: begin
                        dt <= regs[x];
                    end

                    // LD ST, Vx - Fx18
                    // Sets the Sound Timer to Vx
                    16'hF?18: begin
                        st <= regs[x];
                    end

                    // ADD I, Vx - Fx1E
                    // I = I + Vx
                    // I is set to I + Vx
                    16'hF?1E: begin
                        next_i_reg <= reg_i + regs[x];
                        state <= STATE_STORE_I_REG;
                    end

                    // LD F, Vx - Fx29
                    // Sets register I to the location of sprite digit Vx.
                    16'hF?29: begin

                    end

                    // LD B, Vx - Fx33
                    // Stores the binary coded decimal value of Vx in I, I + 1 and I + 2
                    16'hF?33: begin

                    end

                    // LD [I], Vx - Fx55
                    // Stores V0 to Vx starting at reg I's value, I is then set to I + x + 1
                    16'hF?55: begin

                    end

                    // LD Vx, [I] - Fx65
                    // Filles V0 to Vx with memory storaed at reg I's value, I is then set to I + x + 1
                    16'hF?65: begin

                    end
                endcase
            end

            // Do nothing until the next cpu 500hz cycle tick
            STATE_WAIT_CLK: begin
                // Start a new state cycle
                if (timer_cpu_tick) begin
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

            // Store the stack pointer
            STATE_STORE_SP_REG: begin
                sp <= next_sp;
                state <= STATE_WAIT_CLK;
            end
        endcase
    end
endmodule
