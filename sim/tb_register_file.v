`timescale 1ns / 1ps

module tb_register_file;

    // --- Testbench Signals ---
    reg clk;
    reg [4:0] read_reg1, read_reg2;
    reg [4:0] write_reg;
    reg [31:0] write_data;
    reg write_enable;

    wire [31:0] read_data1, read_data2;

    // --- Instantiate DUT ---
    register_file uut (
        .clk(clk),
        .read_reg1(read_reg1),
        .read_reg2(read_reg2),
        .write_reg(write_reg),
        .write_data(write_data),
        .write_enable(write_enable),
        .read_data1(read_data1),
        .read_data2(read_data2)
    );

    // --- Clock Generation ---
    always #5 clk = ~clk;

    // --- Test Sequence ---
    initial begin
        $display("--- Starting Register File Testbench ---");
        clk = 0;
        write_enable = 0;
        read_reg1 = 0;
        read_reg2 = 0;
        write_reg = 0;
        write_data = 0;

        // --- Test 1: Write to x1, read from x1 ---
        #10;
        write_reg = 5'd1;
        write_data = 32'hDEADBEEF;
        write_enable = 1'b1;
        read_reg1 = 5'd1;

        #10; // Wait for posedge clk and propagation
        write_enable = 1'b0; // Disable write for reading
        #1;
        if (read_data1 === 32'hDEADBEEF)
            $display("PASS: Wrote 0xDEADBEEF to x1 and read it back.");
        else
            $display("FAIL: Read %h from x1, expected 0xDEADBEEF.", read_data1);

        // --- Test 2: Write to x2, read x1 and x2 ---
        #10;
        write_reg = 5'd2;
        write_data = 32'h12345678;
        write_enable = 1'b1;
        read_reg1 = 5'd1;
        read_reg2 = 5'd2;

        #10; // Wait for posedge clk
        write_enable = 1'b0;
        #1;
        if (read_data1 === 32'hDEADBEEF && read_data2 === 32'h12345678)
            $display("PASS: Read x1 and x2 correctly after writing to x2.");
        else
            $display("FAIL: Read x1=%h, x2=%h. Expected x1=0xDEADBEEF, x2=0x12345678.", read_data1, read_data2);

        // --- Test 3: Attempt to write to x0 ---
        #10;
        write_reg = 5'd0; // Attempt to write to x0
        write_data = 32'hFFFFFFFF;
        write_enable = 1'b1;
        read_reg1 = 5'd0;

        #10; // Wait for posedge clk
        write_enable = 1'b0;
        #1;
        if (read_data1 === 32'b0)
            $display("PASS: Reading from x0 returns 0 after an attempted write.");
        else
            $display("FAIL: Read %h from x0, expected 0.", read_data1);

        // --- Test 4: Read from x0 (should always be 0) ---
        read_reg1 = 5'd0;
        #1;
        if (read_data1 === 32'b0)
            $display("PASS: Reading from x0 returns 0.");
        else
            $display("FAIL: Read %h from x0, expected 0.", read_data1);


        $display("--- Register File Test Finished ---");
        $finish;
    end

endmodule
