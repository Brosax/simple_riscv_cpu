module register_file(
    input wire clk,
    input wire rst, // Add reset signal
    input wire [4:0] read_reg1,
    input wire [4:0] read_reg2,
    input wire [4:0] write_reg,
    input wire [31:0] write_data,
    input wire write_enable,
    output wire [31:0] read_data1,
    output wire [31:0] read_data2
);

    // 32 registers, 32 bits each
    reg [31:0] registers[0:31];
    integer i;

    // Synchronous write on rising edge, with synchronous reset
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // On reset, initialize all registers to 0
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'b0;
            end
        end else begin
            // Normal write operation
            if (write_enable && write_reg != 5'b0) begin
                registers[write_reg] <= write_data;
            end
        end
    end

    // Asynchronous read
    // Register x0 always returns 0
    assign read_data1 = (read_reg1 == 5'b0) ? 32'b0 : registers[read_reg1];
    assign read_data2 = (read_reg2 == 5'b0) ? 32'b0 : registers[read_reg2];

endmodule
