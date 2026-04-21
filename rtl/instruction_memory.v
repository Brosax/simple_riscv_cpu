module instruction_memory(
    input wire clk,
    input wire [31:0] address,         // Port A: PC fetch
    output wire [31:0] instruction,    // Port A: Instruction out
    
    input wire [31:0] data_addr,       // Port B: Data read address
    input wire [2:0] funct3,           // Port B: Data size/sign extension
    output reg [31:0] data_read        // Port B: Data read out
);

    // 完美支持 32KB
    (* rom_style = "block" *) reg [31:0] mem[0:8191];

    wire [12:0] word_addr_a = address[14:2];
    wire [12:0] word_addr_b = data_addr[14:2];
    
    wire in_range_a = (address[31:15] == 17'h1_0000);
    wire in_range_b = (data_addr[31:15] == 17'h1_0000);

    // 纯同步读取，Vivado 必秒推断 BRAM
    reg [31:0] mem_out_a;
    reg in_range_reg_a;
    
    reg [31:0] raw_data_rdata;
    reg in_range_reg_b;
    reg [2:0] funct3_reg;
    reg [1:0] byte_offset_reg;

    always @(posedge clk) begin
        // Port A
        mem_out_a <= mem[word_addr_a];
        in_range_reg_a <= in_range_a;
        
        // Port B
        raw_data_rdata <= mem[word_addr_b];
        in_range_reg_b <= in_range_b;
        funct3_reg <= funct3;
        byte_offset_reg <= data_addr[1:0];
    end

    // 用组合逻辑决定最后输出，保证 BRAM 推断
    assign instruction = in_range_reg_a ? mem_out_a : 32'h00000013; // NOP
    
    // 纯组合逻辑：CPU 读数据符号扩展
    always @(*) begin
        if (in_range_reg_b) begin
            case (funct3_reg)
                3'b010: data_read = raw_data_rdata; // LW
                3'b001: data_read = byte_offset_reg[1] ? {{16{raw_data_rdata[31]}}, raw_data_rdata[31:16]} : {{16{raw_data_rdata[15]}}, raw_data_rdata[15:0]}; // LH
                3'b000: case (byte_offset_reg) // LB
                            2'b00: data_read = {{24{raw_data_rdata[7]}},  raw_data_rdata[7:0]};
                            2'b01: data_read = {{24{raw_data_rdata[15]}}, raw_data_rdata[15:8]};
                            2'b10: data_read = {{24{raw_data_rdata[23]}}, raw_data_rdata[23:16]};
                            2'b11: data_read = {{24{raw_data_rdata[31]}}, raw_data_rdata[31:24]};
                        endcase
                3'b101: data_read = byte_offset_reg[1] ? {16'b0, raw_data_rdata[31:16]} : {16'b0, raw_data_rdata[15:0]}; // LHU
                3'b100: case (byte_offset_reg) // LBU
                            2'b00: data_read = {24'b0, raw_data_rdata[7:0]};
                            2'b01: data_read = {24'b0, raw_data_rdata[15:8]};
                            2'b10: data_read = {24'b0, raw_data_rdata[23:16]};
                            2'b11: data_read = {24'b0, raw_data_rdata[31:24]};
                        endcase
                default: data_read = 32'b0;
            endcase
        end else begin
            data_read = 32'b0;
        end
    end

    initial begin
        $readmemh("C:/Users/xiangmin/Desktop/TFG/simple_riscv_cpu_freertos/rtl/main.mem", mem);
    end

endmodule