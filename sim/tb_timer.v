`timescale 1ns / 1ps

module tb_timer;

    // --- Inputs ---
    reg clk;
    reg rst;
    reg [31:0] address;
    reg [31:0] write_data;
    reg write_enable;

    // --- Outputs ---
    wire [31:0] read_data;
    wire interrupt;

    // --- Instantiate DUT ---
    timer uut (
        .clk(clk),
        .rst(rst),
        .address(address),
        .write_data(write_data),
        .write_enable(write_enable),
        .read_data(read_data),
        .interrupt(interrupt)
    );

    // --- Memory Mapped Addresses ---
    localparam ADDR_MTIME_LOW  = 32'hFFFF0000;
    localparam ADDR_MTIME_HIGH = 32'hFFFF0004;
    localparam ADDR_MTIMECMP_LOW = 32'hFFFF0008;
    localparam ADDR_MTIMECMP_HIGH = 32'hFFFF000C;

    // --- Clock Generation ---
    always #5 clk = ~clk;

    integer cycles = 0;
    always @(posedge clk) cycles <= cycles + 1;

    initial begin
        clk = 0;
        rst = 1;
        address = 0;
        write_data = 0;
        write_enable = 0;
        $display("--- Starting Timer Testbench ---");

        #10;
        rst = 0;
        #10;

        // --- Test 1: Check if mtime increments ---
        address = ADDR_MTIME_LOW;
        #1;
        if (read_data > 0) 
            $display("PASS: mtime is incrementing (current value: %d)", read_data);
        else
            $display("FAIL: mtime does not appear to be incrementing.");

        // --- Test 2: Write to mtimecmp ---
        address = ADDR_MTIMECMP_LOW;
        write_data = 32'd50; // Set interrupt to trigger at cycle 50
        write_enable = 1;
        #10; // posedge clk
        write_enable = 0;

        address = ADDR_MTIMECMP_LOW;
        #1;
        if (read_data == 32'd50)
            $display("PASS: Wrote to mtimecmp successfully.");
        else
            $display("FAIL: Could not write to mtimecmp. Expected 50, got %d", read_data);

        // --- Test 3: Wait for interrupt ---
        $display("Info: Waiting for mtime to reach mtimecmp (50). Current mtime is %d.", cycles);
        wait (interrupt == 1'b1);

        if (cycles >= 50) begin
            $display("PASS: Interrupt triggered at cycle %d (mtime >= mtimecmp).", cycles);
        end else begin
            $display("FAIL: Interrupt triggered prematurely at cycle %d.", cycles);
        end

        #20;
        if (interrupt == 1'b1)
            $display("PASS: Interrupt remains high after being triggered.");
        else
            $display("FAIL: Interrupt did not remain high.");


        $display("--- Timer Test Finished ---");
        $finish;
    end

endmodule
