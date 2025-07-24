module register_file(
    input wire clk,
    input wire [4:0] read_reg1,
    input wire [4:0] read_reg2,
    input wire [4:0] write_reg,
    input wire [31:0] write_data,
    input wire write_enable,
    output wire [31:0] read_data1,
    output wire [31:0] read_data2
);

    // Banco de 32 registros de 32 bits
    reg [31:0] registers[0:31];

    // Escritura síncrona en el flanco de subida
    always @(posedge clk) begin
        if (write_enable && write_reg != 5'b0) begin
            registers[write_reg] <= write_data;
        end
    end

    // Lectura asíncrona
    // El registro x0 siempre devuelve 0
    assign read_data1 = (read_reg1 == 5'b0) ? 32'b0 : registers[read_reg1];
    assign read_data2 = (read_reg2 == 5'b0) ? 32'b0 : registers[read_reg2];

endmodule
