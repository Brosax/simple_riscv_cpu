module register_file(
    input wire clk,
    input wire rst,
    input wire [4:0] read_reg1,
    input wire [4:0] read_reg2,
    input wire [4:0] write_reg,
    input wire [31:0] write_data,
    input wire write_enable,
    output wire [31:0] read_data1,
    output wire [31:0] read_data2,
    // Debug access ports (JTAG)
    input wire [4:0]  debug_read_addr,
    input wire        debug_write_enable,
    input wire [31:0] debug_write_data,
    output wire [31:0] debug_read_data
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
            // Debug write (higher priority than normal write)
            if (debug_write_enable && debug_read_addr != 5'b0) begin
                registers[debug_read_addr] <= debug_write_data;
            end
        end
    end

    // Asynchronous read
    // Register x0 always returns 0
    assign read_data1 = (read_reg1 == 5'b0) ? 32'b0 : registers[read_reg1];
    assign read_data2 = (read_reg2 == 5'b0) ? 32'b0 : registers[read_reg2];

    // Debug read (asynchronous)
    assign debug_read_data = (debug_read_addr == 5'b0) ? 32'b0 : registers[debug_read_addr];

endmodule
