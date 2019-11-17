sim:
	iverilog -o ./chip8.out -s chip8 -I src -I sim ./src/chip8.v

.PHONY: sim