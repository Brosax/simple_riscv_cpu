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

    // Lógica de reset
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            gpio_data_reg <= 32'b0;
            gpio_dir_reg  <= 32'b0; // Por defecto, todos los pines como entrada
        end
    end

    // Lógica de escritura (E/S mapeada en memoria)
    always @(posedge clk) begin
        if (write_enable) begin
            case (address)
                32'hFFFF0010: gpio_data_reg <= write_data; // Escribir en el registro de datos
                32'hFFFF0014: gpio_dir_reg  <= write_data; // Escribir en el registro de dirección
                default: ; // No hacer nada para otras direcciones
            endcase
        end
    end

    // Lógica de lectura (E/S mapeada en memoria)
    assign read_data = (address == 32'hFFFF0010) ? {24'b0, gpio_pins} : // Leer el estado actual de los pines
                       (address == 32'hFFFF0014) ? gpio_dir_reg :      // Leer el registro de dirección
                       32'hxxxxxxxx; // Valor por defecto para direcciones no mapeadas

    // Control de los pines inout
    genvar i;
    for (i = 0; i < 8; i = i + 1) begin : gpio_pin_control
        assign gpio_pins[i] = gpio_dir_reg[i] ? gpio_data_reg[i] : 1'bz; // Si es salida, usa gpio_data_reg; si es entrada, alta impedancia
    end

endmodule
