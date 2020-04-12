# Allow to only run one test
ifneq ($(TEST),)
	TESTBENCHES = "./tests/$(TEST)_tb.v"
else
	TESTBENCHES = $(wildcard ./tests/*_tb.v)
endif

.PHONY: build
build:
	@mkdir -p build
	iverilog -o ./build/chip8.out -s chip8 -I src -I sim ./src/chip8.v

.PHONY: sim
sim:
	@mkdir -p build
	iverilog -o ./build/chip8.out -s chip8 -I src -I sim ./src/chip8.v

.PHONY: test
test:
	@mkdir -p build/out build/vcd
	@exec 5>&1; \
	for f in $(TESTBENCHES); do \
		echo "Testing: $$f"; \
		OUT_PATH="./build/out/$$(basename $$f .v).out"; \
		VCD_PATH="../build/vcd/$$(basename $$f .v).vcd"; \
		rm -rf "$$OUT_PATH"; \
		out=$$(iverilog -o $$OUT_PATH -I src -I sim -I tests -DVCD_PATH=\"$$VCD_PATH\" $$f 2>&1); \
		if [ "$$out" = "" ]; then \
			out=$$(cd src; ../$$OUT_PATH | tee /dev/fd/5 2>&1); \
			if $$(echo $$out | grep -q "FAILED"); then \
				exit 1; \
			fi \
		else \
			echo "Test failure $$f: $$out"; \
			exit 1; \
		fi \
	done; \
	echo "All OK"

.PHONY: clean
clean:
	rm -rf ./build/