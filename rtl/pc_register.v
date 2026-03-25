module pc_register(
    input wire clk,
    input wire rst,
    input wire stall,        // JTAG debug: freeze PC while debug access is in progress
    input wire [31:0] pc_in,
    output reg [31:0] pc_out
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pc_out <= 32'h80000000; // El PC debe empezar en la dirección de inicio de los tests
    end else if (!stall) begin
        pc_out <= pc_in;
    end
end

endmodule
