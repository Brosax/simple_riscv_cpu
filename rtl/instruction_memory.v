module instruction_memory(
    input wire clk,
    input wire [31:0] address,
    output wire [31:0] instruction
);

    // 完美支持 32KB
    (* rom_style = "block" *) reg [31:0] mem[0:8191];

    wire [12:0] word_addr = address[14:2];
    wire in_range = (address[31:15] == 17'h1_0000);

    // 纯同步读取，Vivado 必秒推断 BRAM
    reg [31:0] mem_out;
    reg in_range_reg;

    always @(posedge clk) begin
        mem_out <= mem[word_addr];
        in_range_reg <= in_range;
    end

    // 用组合逻辑决定最后输出，保证 BRAM 推断
    assign instruction = in_range_reg ? mem_out : 32'h00000013; // NOP

    initial begin
        // 记得确认这个绝对路径是你电脑上的
        $readmemh("C:/Users/xiangmin/Desktop/TFG/simple_riscv_cpu/rtl/test_hello.mem", mem);
    end

endmodule