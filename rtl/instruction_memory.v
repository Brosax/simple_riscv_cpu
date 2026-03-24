module instruction_memory(
	input wire [31:0] address,
	output wire [31:0] instruction
);

	// Instruction memory: 8192 instructions (32KB)
	reg [31:0] mem[0:8191];

	// Address mapping: subtract base address and divide by 4 for word addressing
	// Includes bounds checking for safety
	wire [31:0] word_addr = (address - 32'h80000000) >> 2;
	assign instruction = (word_addr < 8192) ? mem[word_addr] : 32'h00000013; // NOP (addi x0,x0,0)

endmodule
