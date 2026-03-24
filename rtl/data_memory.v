module data_memory(
	input wire clk,
	input wire [31:0] address,
	input wire [31:0] write_data,
	input wire write_enable,
	input wire [2:0] funct3,
	output reg [31:0] read_data
);

	// Data memory: 8KB (8192 bytes)
	reg [7:0] mem[0:8191];

	// Address mapping: use lower 13 bits to index into 8KB space
	wire [12:0] local_addr = address[12:0];

	// Write logic
	always @(posedge clk) begin
		if (write_enable) begin
			case (funct3)
				3'b000: // SB
					mem[local_addr] <= write_data[7:0];
				3'b001: begin // SH
					mem[local_addr] <= write_data[7:0];
					mem[local_addr+1] <= write_data[15:8];
				end
				3'b010: begin // SW
					mem[local_addr] <= write_data[7:0];
					mem[local_addr+1] <= write_data[15:8];
					mem[local_addr+2] <= write_data[23:16];
					mem[local_addr+3] <= write_data[31:24];
				end
				default: ;
			endcase
		end
	end

	// Read logic
	always @(*) begin
		case (funct3)
			3'b010: // LW
				read_data = {mem[local_addr+3], mem[local_addr+2], mem[local_addr+1], mem[local_addr]};
			3'b001: // LH
				read_data = {{16{mem[local_addr+1][7]}}, mem[local_addr+1], mem[local_addr]};
			3'b000: // LB
				read_data = {{24{mem[local_addr][7]}}, mem[local_addr]};
			3'b101: // LHU
				read_data = {16'b0, mem[local_addr+1], mem[local_addr]};
			3'b100: // LBU
				read_data = {24'b0, mem[local_addr]};
			default: read_data = 32'b0;
		endcase
	end

endmodule
