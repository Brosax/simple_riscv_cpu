module timer(
    input wire clk,
    input wire rst,
    input wire [31:0] address,      // Dirección desde la CPU
    input wire [31:0] write_data,   // Datos a escribir desde la CPU
    input wire write_enable,        // Habilitación de escritura desde la CPU
    output wire [31:0] read_data,   // Datos a leer para la CPU
    output wire interrupt
);

    reg [63:0] mtime_reg;
    reg [63:0] mtimecmp_reg;

	// Combined reset, counter and write logic (fixes multiple driver conflict)
	always @(posedge clk or posedge rst) begin
		if (rst) begin
			mtime_reg <= 64'd0;
			mtimecmp_reg <= 64'd0;
		end else begin
			mtime_reg <= mtime_reg + 64'd1;
			if (write_enable) begin
				case (address)
					32'hFFFF0008: mtimecmp_reg[31:0] <= write_data;
					32'hFFFF000C: mtimecmp_reg[63:32] <= write_data;
					default: ;
				endcase
			end
		end
	end

	// Read logic (memory-mapped I/O)
	assign read_data = (address == 32'hFFFF0000) ? mtime_reg[31:0] :
		(address == 32'hFFFF0004) ? mtime_reg[63:32] :
		(address == 32'hFFFF0008) ? mtimecmp_reg[31:0] :
		(address == 32'hFFFF000C) ? mtimecmp_reg[63:32] :
		32'b0;

    // Lógica de interrupción: se activa cuando mtime >= mtimecmp
    assign interrupt = (mtime_reg >= mtimecmp_reg);

endmodule
