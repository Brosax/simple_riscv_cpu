module pc_register(
    input wire clk,
    input wire rst,
    input wire [31:0] pc_in,
    output reg [31:0] pc_out
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pc_out <= 32'h80000000; // El PC debe empezar en la dirección de inicio de los tests
    end else begin
        pc_out <= pc_in;
    end
end

endmodule
