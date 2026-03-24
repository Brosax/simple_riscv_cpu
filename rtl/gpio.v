module gpio(
    input wire clk,
    input wire rst,
    input wire [31:0] address,      // Dirección desde la CPU
    input wire [31:0] write_data,   // Datos a escribir desde la CPU
    input wire write_enable,        // Habilitación de escritura desde la CPU
    output wire [31:0] read_data,   // Datos a leer para la CPU
    inout wire [7:0] gpio_pins      // Pines físicos del GPIO
);

    reg [31:0] gpio_data_reg; // Registro para el valor de los pines (salida)
    reg [31:0] gpio_dir_reg;  // Registro para la dirección de los pines (0=entrada, 1=salida)

    // Combined reset and write logic (fixes multiple driver conflict)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            gpio_data_reg <= 32'b0;
            gpio_dir_reg <= 32'b0; // Default: all pins as input
        end else if (write_enable) begin
            case (address)
                32'hFFFF0010: gpio_data_reg <= write_data; // Write to data register
                32'hFFFF0014: gpio_dir_reg <= write_data; // Write to direction register
                default: ;
            endcase
        end
    end

    // Read logic (memory-mapped I/O)
    assign read_data = (address == 32'hFFFF0010) ? {24'b0, gpio_pins} : // Read actual pin state
                       (address == 32'hFFFF0014) ? gpio_dir_reg :       // Read direction register
                       32'b0;

    // Tristate pin control
    genvar i;
    for (i = 0; i < 8; i = i + 1) begin : gpio_pin_control
        assign gpio_pins[i] = gpio_dir_reg[i] ? gpio_data_reg[i] : 1'bz;
    end

endmodule
