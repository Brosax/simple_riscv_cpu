module data_memory(
    input wire clk,
    input wire [31:0] address,
    input wire [31:0] write_data,
    input wire write_enable,
    input wire [2:0] funct3,
    output reg [31:0] read_data,
    input wire        debug_mem_read,
    input wire [31:0] debug_mem_addr,
    input wire        debug_mem_write,
    input wire [31:0] debug_mem_wdata,
    input wire [3:0]  debug_mem_wstrb,
    output reg [31:0] debug_mem_rdata
);

    (* ram_style = "block" *) reg [7:0] mem_b0 [0:8191];
    (* ram_style = "block" *) reg [7:0] mem_b1 [0:8191];
    (* ram_style = "block" *) reg [7:0] mem_b2 [0:8191];
    (* ram_style = "block" *) reg [7:0] mem_b3 [0:8191];

    integer i;
    initial begin
        for (i = 0; i < 8192; i = i + 1) begin
            mem_b0[i] = 8'b0;
            mem_b1[i] = 8'b0;
            mem_b2[i] = 8'b0;
            mem_b3[i] = 8'b0;
        end
    end

    wire [12:0] word_addr     = address[14:2];
    wire [12:0] dbg_word_addr = debug_mem_addr[14:2];
    wire [1:0]  byte_offset   = address[1:0];

    // 写掩码组合逻辑
    reg [3:0] we_mask;
    always @(*) begin
        we_mask = 4'b0000;
        if (write_enable) begin
            case (funct3)
                3'b010: we_mask = 4'b1111;
                3'b001: we_mask = byte_offset[1] ? 4'b1100 : 4'b0011;
                3'b000: case (byte_offset)
                            2'b00: we_mask = 4'b0001;
                            2'b01: we_mask = 4'b0010;
                            2'b10: we_mask = 4'b0100;
                            2'b11: we_mask = 4'b1000;
                        endcase
                default: we_mask = 4'b0000;
            endcase
        end
    end

    reg [31:0] aligned_wdata;
    always @(*) begin
        case (funct3)
            3'b001: aligned_wdata = {2{write_data[15:0]}};
            3'b000: aligned_wdata = {4{write_data[7:0]}};
            default: aligned_wdata = write_data;
        endcase
    end

    reg [31:0] raw_cpu_rdata;

    // 纯同步真双口 RAM 模板
    // 端口 A (CPU)
    always @(posedge clk) begin
        if (we_mask[0]) mem_b0[word_addr] <= aligned_wdata[7:0];
        if (we_mask[1]) mem_b1[word_addr] <= aligned_wdata[15:8];
        if (we_mask[2]) mem_b2[word_addr] <= aligned_wdata[23:16];
        if (we_mask[3]) mem_b3[word_addr] <= aligned_wdata[31:24];
        raw_cpu_rdata <= {mem_b3[word_addr], mem_b2[word_addr], mem_b1[word_addr], mem_b0[word_addr]};
    end

    // 端口 B (JTAG)
    always @(posedge clk) begin
        if (debug_mem_write) begin
            if (debug_mem_wstrb[0]) mem_b0[dbg_word_addr] <= debug_mem_wdata[7:0];
            if (debug_mem_wstrb[1]) mem_b1[dbg_word_addr] <= debug_mem_wdata[15:8];
            if (debug_mem_wstrb[2]) mem_b2[dbg_word_addr] <= debug_mem_wdata[23:16];
            if (debug_mem_wstrb[3]) mem_b3[dbg_word_addr] <= debug_mem_wdata[31:24];
        end
        // Always read memory data sequentially to ensure BRAM mapping
        debug_mem_rdata <= {mem_b3[dbg_word_addr], mem_b2[dbg_word_addr], mem_b1[dbg_word_addr], mem_b0[dbg_word_addr]};
    end

    // 纯组合逻辑：CPU 读数据符号扩展
    always @(*) begin
        case (funct3)
            3'b010: read_data = raw_cpu_rdata; // LW
            3'b001: read_data = byte_offset[1] ? {{16{raw_cpu_rdata[31]}}, raw_cpu_rdata[31:16]} : {{16{raw_cpu_rdata[15]}}, raw_cpu_rdata[15:0]}; // LH
            3'b000: case (byte_offset) // LB
                        2'b00: read_data = {{24{raw_cpu_rdata[7]}},  raw_cpu_rdata[7:0]};
                        2'b01: read_data = {{24{raw_cpu_rdata[15]}}, raw_cpu_rdata[15:8]};
                        2'b10: read_data = {{24{raw_cpu_rdata[23]}}, raw_cpu_rdata[23:16]};
                        2'b11: read_data = {{24{raw_cpu_rdata[31]}}, raw_cpu_rdata[31:24]};
                    endcase
            3'b101: read_data = byte_offset[1] ? {16'b0, raw_cpu_rdata[31:16]} : {16'b0, raw_cpu_rdata[15:0]}; // LHU
            3'b100: case (byte_offset) // LBU
                        2'b00: read_data = {24'b0, raw_cpu_rdata[7:0]};
                        2'b01: read_data = {24'b0, raw_cpu_rdata[15:8]};
                        2'b10: read_data = {24'b0, raw_cpu_rdata[23:16]};
                        2'b11: read_data = {24'b0, raw_cpu_rdata[31:24]};
                    endcase
            default: read_data = 32'b0;
        endcase
    end
endmodule