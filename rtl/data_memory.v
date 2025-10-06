module data_memory(
    input wire clk,
    input wire [31:0] address,
    input wire [31:0] write_data,
    input wire write_enable,
    input wire [2:0] funct3,
    output reg [31:0] read_data
);

    // Memoria para almacenar los datos (ej: 1024 palabras de 32 bits -> 4096 bytes)
    //reg [7:0] mem[0:4095];
    reg [7:0] mem[0:8192];
    // --- Lógica de Escritura ---
    always @(posedge clk) begin
        if (write_enable) begin
            case (funct3)
                3'b000: // SB
                    mem[address] <= write_data[7:0];
                3'b001: begin // SH
                    mem[address]   <= write_data[7:0];
                    mem[address+1] <= write_data[15:8];
                end
                3'b010: begin // SW
                    mem[address]   <= write_data[7:0];
                    mem[address+1] <= write_data[15:8];
                    mem[address+2] <= write_data[23:16];
                    mem[address+3] <= write_data[31:24];
                end
            endcase
        end
    end

    // --- Lógica de Lectura ---
    always @(*) begin
        case (funct3)
            3'b010: // LW
                read_data = {mem[address+3], mem[address+2], mem[address+1], mem[address]};
            3'b001: // LH
                read_data = {{16{mem[address+1][7]}}, mem[address+1], mem[address]};
            3'b000: // LB
                read_data = {{24{mem[address][7]}}, mem[address]};
            3'b101: // LHU
                read_data = {16'b0, mem[address+1], mem[address]};
            3'b100: // LBU
                read_data = {24'b0, mem[address]};
            default: read_data = 32'hxxxxxxxx;
        endcase
    end

endmodule
