module riscv_core(
	input wire clk,
	input wire rst,
	output wire timer_interrupt,
	inout wire [7:0] gpio_pins,
	output wire host_write_enable,
	output wire [31:0] host_data_out,
	// Debug / JTAG interface
	input wire        debug_stall,         // freeze PC during debug access
	output wire       debug_stall_status,  // current stall state
	output wire [31:0] debug_pc_value,     // current PC value
	input wire [4:0]  debug_reg_addr,
	input wire        debug_reg_read,
	input wire        debug_reg_write,
	input wire [31:0] debug_reg_wdata,
	output wire [31:0] debug_reg_rdata,
	input wire        debug_mem_read,
	input wire [31:0] debug_mem_addr,
	input wire        debug_mem_write,
	input wire [31:0] debug_mem_wdata,
	input wire [1:0]  debug_mem_wstrb,
	output wire [31:0] debug_mem_rdata
);

	// Opcode definitions (shared with control_unit.v)
	localparam OPCODE_R_TYPE = 7'b0110011;
	localparam OPCODE_I_TYPE_ARITH = 7'b0010011;
	localparam OPCODE_I_TYPE_LOAD = 7'b0000011;
	localparam OPCODE_S_TYPE = 7'b0100011;
	localparam OPCODE_B_TYPE = 7'b1100011;
	localparam OPCODE_JAL = 7'b1101111;
	localparam OPCODE_JALR = 7'b1100111;
	localparam OPCODE_LUI = 7'b0110111;
	localparam OPCODE_AUIPC = 7'b0010111;

	// Memory-mapped I/O address constants
	// Note: 0x80001000 is used as the data section address by pre-compiled ISA tests
	// (linked at 0x00000000, data ALIGN(0x1000)). Using 0x80002000 avoids collisions.
	localparam TOHOST_ADDR = 32'h80002000;

	// Datapath signals
	wire [31:0] pc_current, pc_next, pc_plus_4, pc_branch;

	// Debug stall state: CPU is halted whenever debug_stall is asserted.
	// JTAG clears it by driving debug_stall=0 (typically via DEBUG_RESET command).
	reg cpu_stall;
	always @(posedge clk or posedge rst) begin
		if (rst)   cpu_stall <= 1'b0;
		else        cpu_stall <= debug_stall;
	end
	wire stall = cpu_stall;
	wire [31:0] instruction;
	wire [31:0] imm_extended;
	wire [31:0] alu_result, alu_operand2;
	wire [31:0] reg_read_data1, reg_read_data2;
	wire [31:0] mem_read_data;
	wire [31:0] write_back_data;

	// Control signals
	wire alu_src, mem_to_reg, reg_write, mem_read, mem_write, branch, jump;
	wire [1:0] alu_op;
	wire [3:0] alu_control_signal;
	wire alu_zero_flag;

	// Instruction decode
	wire [6:0] opcode = instruction[6:0];
	wire [4:0] rs1 = instruction[19:15];
	wire [4:0] rs2 = instruction[24:20];
	wire [4:0] rd = instruction[11:7];
	wire [2:0] funct3 = instruction[14:12];
	wire funct7_bit5 = instruction[30];

	// Peripheral signals
	wire [31:0] timer_read_data;
	wire [31:0] gpio_read_data;
	wire [31:0] mem_read_data_from_data_mem;

	// Address decode logic (Memory-Mapped I/O)
	// Address ranges:
	// Data Memory: [0x00000000 - 0xFFFEFFFF]
	// Timer: [0xFFFF0000 - 0xFFFF000F]
	// GPIO: [0xFFFF0010 - 0xFFFF001F]
	wire is_timer_access = (alu_result >= 32'hFFFF0000) && (alu_result <= 32'hFFFF000F);
	wire is_gpio_access = (alu_result >= 32'hFFFF0010) && (alu_result <= 32'hFFFF001F);
	wire is_tohost_access = (alu_result == TOHOST_ADDR);
	wire is_data_mem_access = !(is_timer_access || is_gpio_access || is_tohost_access);

	// Read/write enable signals for each component
	wire data_mem_read_enable = mem_read && is_data_mem_access;
	wire data_mem_write_enable = mem_write && is_data_mem_access;

	wire timer_read_enable = mem_read && is_timer_access;
	wire timer_write_enable = mem_write && is_timer_access;

	wire gpio_read_enable = mem_read && is_gpio_access;
	wire gpio_write_enable = mem_write && is_gpio_access;

	// Module instantiations

	// 1. PC Register
	pc_register pc_reg(
		.clk(clk),
		.rst(rst),
		.stall(stall),
		.pc_in(pc_next),
		.pc_out(pc_current)
	);

	// 2. Instruction Memory
	instruction_memory instr_mem(
		.address(pc_current),
		.instruction(instruction)
	);

	// 3. Control Unit
	control_unit ctrl_unit(
		.opcode(opcode),
		.alu_src(alu_src),
		.alu_op(alu_op),
		.mem_to_reg(mem_to_reg),
		.reg_write(reg_write),
		.mem_read(mem_read),
		.mem_write(mem_write),
		.branch(branch),
		.jump(jump)
	);

	// 4. Register File
	register_file reg_file(
		.clk(clk),
		.rst(rst),
		.read_reg1(rs1),
		.read_reg2(rs2),
		.write_reg(rd),
		.write_data(write_back_data),
		.write_enable(reg_write),
		.read_data1(reg_read_data1),
		.read_data2(reg_read_data2),
		.debug_read_addr(debug_reg_addr),
		.debug_write_enable(debug_reg_write),
		.debug_write_data(debug_reg_wdata),
		.debug_read_data(debug_reg_rdata)
	);

	// 5. Immediate Generator
	immediate_generator imm_gen(
		.instruction(instruction),
		.imm_extended(imm_extended)
	);

	// 6. ALU Control Unit
	alu_control_unit alu_ctrl(
		.alu_op(alu_op),
		.funct3(funct3),
		.funct7_bit5(funct7_bit5),
		.alu_control(alu_control_signal)
	);

	// 7. ALU
	wire [31:0] alu_operand1;
	assign alu_operand1 = (opcode == OPCODE_AUIPC) ? pc_current :
		(opcode == OPCODE_LUI) ? 32'b0 :
		reg_read_data1;

	assign alu_operand2 = alu_src ? imm_extended : reg_read_data2;
	alu alu_inst(
		.operand1(alu_operand1),
		.operand2(alu_operand2),
		.alu_control(alu_control_signal),
		.result(alu_result),
		.zero(alu_zero_flag)
	);

	// 8. Data Memory
	data_memory data_mem(
		.clk(clk),
		.address(alu_result),
		.write_data(reg_read_data2),
		.write_enable(data_mem_write_enable),
		.read_data(mem_read_data_from_data_mem),
		.funct3(funct3),
		.debug_mem_read(debug_mem_read),
		.debug_mem_addr(debug_mem_addr),
		.debug_mem_write(debug_mem_write),
		.debug_mem_wdata(debug_mem_wdata),
		.debug_mem_wstrb(debug_mem_wstrb),
		.debug_mem_rdata(debug_mem_rdata)
	);

	// 9. Timer
	timer timer_inst(
		.clk(clk),
		.rst(rst),
		.address(alu_result),
		.write_data(reg_read_data2),
		.write_enable(timer_write_enable),
		.read_data(timer_read_data),
		.interrupt(timer_interrupt)
	);

	// 10. GPIO
	gpio gpio_inst(
		.clk(clk),
		.rst(rst),
		.address(alu_result),
		.write_data(reg_read_data2),
		.write_enable(gpio_write_enable),
		.read_data(gpio_read_data),
		.gpio_pins(gpio_pins)
	);

	// tohost logic for riscv-tests
	assign host_write_enable = mem_write && (alu_result == TOHOST_ADDR);
	assign host_data_out = reg_read_data2;

	// Debug outputs
	assign debug_stall_status = cpu_stall;
	assign debug_pc_value = pc_current;

	// Read data multiplexer
	assign mem_read_data = is_timer_access ? timer_read_data :
		is_gpio_access ? gpio_read_data :
		mem_read_data_from_data_mem;

	// Next PC logic
	assign pc_plus_4 = pc_current + 4;
	wire [31:0] pc_target_imm = pc_current + imm_extended;
	wire [31:0] pc_target_jalr = {alu_result[31:1], 1'b0};

	// Branch condition logic (using logical operators)
	wire take_branch;
	assign take_branch = (branch && (
		(funct3 == 3'b000 && alu_zero_flag) ||  // BEQ
		(funct3 == 3'b001 && ~alu_zero_flag) || // BNE
		(funct3 == 3'b100 && alu_result[0]) ||  // BLT
		(funct3 == 3'b101 && ~alu_result[0]) || // BGE
		(funct3 == 3'b110 && alu_result[0]) ||  // BLTU
		(funct3 == 3'b111 && ~alu_result[0])    // BGEU
	));

	// PC multiplexer
	assign pc_next = (jump && opcode == OPCODE_JAL) ? pc_target_imm :
		(jump && opcode == OPCODE_JALR) ? pc_target_jalr :
		take_branch ? pc_target_imm :
		pc_plus_4;

	// Write back logic
	assign write_back_data = jump ? pc_plus_4 : (mem_to_reg ? mem_read_data : alu_result);

	// Debug trace (simulation only)
`ifdef SIMULATION
	always @(posedge clk) begin
		if (!rst) begin
			$display("PC: %h, INST: %h, reg_write: %b, rd: %d, wb_data: %h, alu_res: %h, op1: %h, op2: %h, alu_ctrl: %b",
				pc_current, instruction, reg_write, rd, write_back_data, alu_result, alu_operand1, alu_operand2, alu_control_signal);
		end
	end
`endif

endmodule
