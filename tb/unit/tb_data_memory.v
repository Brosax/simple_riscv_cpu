`timescale 1ns / 1ps

module tb_data_memory;

    // --- Inputs ---
    reg clk;
    reg [31:0] address;
    reg [31:0] write_data;
    reg write_enable;
    reg [2:0] funct3;

    // --- Output ---
    wire [31:0] read_data;
    wire [31:0] debug_mem_rdata;
    assign debug_mem_rdata = 32'b0;

    // --- Instantiate DUT ---
    data_memory uut (
        .clk(clk),
        .address(address),
        .write_data(write_data),
        .write_enable(write_enable),
        .funct3(funct3),
        .read_data(read_data),
        .debug_mem_read(1'b0),
        .debug_mem_addr(32'b0),
        .debug_mem_write(1'b0),
        .debug_mem_wdata(32'b0),
        .debug_mem_wstrb(2'b11),
        .debug_mem_rdata(debug_mem_rdata)
    );

    // --- Funct3 Opcodes ---
    localparam FUNCT3_SB = 3'b000;
    localparam FUNCT3_SH = 3'b001;
    localparam FUNCT3_SW = 3'b010;
    localparam FUNCT3_LB = 3'b000;
    localparam FUNCT3_LH = 3'b001;
    localparam FUNCT3_LW = 3'b010;
    localparam FUNCT3_LBU = 3'b100;
    localparam FUNCT3_LHU = 3'b101;

    // --- Clock Generation ---
    initial clk = 0;
    always #5 clk = ~clk;

    // Note: read_data is synchronous - requires a clock edge after write to get new value
    task check_read;
        input [31:0] addr;
        input [2:0] f3;
        input [31:0] expected_data;
        input [255:0] test_name;
        begin
            address = addr;
            funct3 = f3;
            write_enable = 0;
            @(posedge clk);  // Wait for clock edge — synchronous read needs this
            #1;
            if (read_data === expected_data) begin
                $display("PASS: %s", test_name);
            end else begin
                $display("FAIL: %s -> Expected: %h, Got: %h", test_name, expected_data, read_data);
            end
        end
    endtask

    task write_mem;
        input [31:0] addr;
        input [31:0] data;
        input [2:0] f3;
        begin
            address = addr;
            write_data = data;
            funct3 = f3;
            write_enable = 1;
            @(posedge clk);  // Write on clock edge
            write_enable = 0;
        end
    endtask

    initial begin
        clk = 0;
        $display("--- Starting Data Memory Testbench ---");

        // --- Test 1: Word (SW/LW) ---
        write_mem(32'd100, 32'hDEADBEEF, FUNCT3_SW);
        check_read(32'd100, FUNCT3_LW, 32'hDEADBEEF, "SW/LW Word");

        // --- Test 2: Half-word (SH/LH/LHU) ---
        write_mem(32'd200, 32'h1234ABCD, FUNCT3_SH);
        check_read(32'd200, FUNCT3_LH, 32'hFFFFABCD, "SH/LH Half-word (signed)");
        check_read(32'd200, FUNCT3_LHU, 32'h0000ABCD, "SH/LHU Half-word (unsigned)");

        // --- Test 3: Byte (SB/LB/LBU) ---
        write_mem(32'd300, 32'hFFFFFF88, FUNCT3_SB);
        check_read(32'd300, FUNCT3_LB, 32'hFFFFFF88, "SB/LB Byte (signed)");
        check_read(32'd300, FUNCT3_LBU, 32'h00000088, "SB/LBU Byte (unsigned)");

        // --- Test 4: Overwriting data ---
        write_mem(32'd400, 32'h11223344, FUNCT3_SW); // Write a full word
        write_mem(32'd401, 32'hFFFF5566, FUNCT3_SH); // Overwrite bytes at 401, 402 with 0x5566
        check_read(32'd400, FUNCT3_LW, 32'h11556644, "Overwrite with SH");

        $display("--- Data Memory Test Finished ---");
        $finish;
    end

endmodule
