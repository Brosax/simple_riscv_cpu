`timescale 1ns / 1ps

module tb_gpio;

    // --- Inputs ---
    reg clk;
    reg rst;
    reg [31:0] address;
    reg [31:0] write_data;
    reg write_enable;

    // --- Output ---
    wire [31:0] read_data;

    // --- Inout ---
    wire [7:0] gpio_pins_wire;
    reg  [7:0] gpio_pins_reg;

    // --- Instantiate DUT ---
    gpio uut (
        .clk(clk),
        .rst(rst),
        .address(address),
        .write_data(write_data),
        .write_enable(write_enable),
        .read_data(read_data),
        .gpio_pins(gpio_pins_wire)
    );

    // --- Drive the inout pins ---
    assign gpio_pins_wire = gpio_pins_reg;

    // --- Clock Generation ---
    always #5 clk = ~clk;

    // --- Test Tasks ---
    task reset_dut;
        begin
            rst = 1;
            #10;
            rst = 0;
            #5;
            $display("--- DUT Reset ---");
        end
    endtask

    task write_reg;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            address = addr;
            write_data = data;
            write_enable = 1;
            @(posedge clk);
            write_enable = 0;
            address = 32'hxxxxxxxx;
        end
    endtask

    task check_read;
        input [31:0] addr;
        input [31:0] expected_data;
        input [255:0] test_name;
        begin
            @(posedge clk);
            address = addr;
            @(posedge clk);
            #1; // Let combinatorial logic settle
            if (read_data === expected_data)
                $display("PASS: %s", test_name);
            else
                $display("FAIL: %s -> Expected: %h, Got: %h", test_name, expected_data, read_data);
            address = 32'hxxxxxxxx;
        end
    endtask


    // --- Test Sequence ---
    initial begin
        $display("--- Starting GPIO Testbench ---");
        clk = 0;
        gpio_pins_reg = 8'hzz;

        reset_dut();

        // 1. Test setting direction register
        $display("--- Test 1: Set GPIO direction to output ---");
        write_reg(32'hFFFF0014, 32'h000000FF); // Set all 8 pins to output
        check_read(32'hFFFF0014, 32'h000000FF, "GPIO direction register read back");

        // 2. Test writing data to output pins
        $display("--- Test 2: Write data to GPIO output pins ---");
        write_reg(32'hFFFF0010, 32'h000000A5); // Write 0xA5 to data register
        #1;
        if (gpio_pins_wire === 8'hA5)
            $display("PASS: Data 0xA5 written to GPIO pins correctly.");
        else
            $display("FAIL: Incorrect data on GPIO pins: %h", gpio_pins_wire);

        // 3. Test setting direction to input
        $display("--- Test 3: Set GPIO direction to input ---");
        write_reg(32'hFFFF0014, 32'h00000000); // Set all 8 pins to input
        #1;
        if (gpio_pins_wire === 8'hzz)
             $display("PASS: GPIO pins are high-impedance.");
        else
             $display("FAIL: GPIO pins are not high-impedance: %h", gpio_pins_wire);


        // 4. Test reading data from input pins
        $display("--- Test 4: Read data from GPIO input pins ---");
        gpio_pins_reg = 8'h5A; // Drive pins from external source
        check_read(32'hFFFF0010, 32'h0000005A, "Read data from GPIO input pins");
        gpio_pins_reg = 8'hzz; // Release pins

        $display("--- GPIO Test Finished ---");
        $finish;
    end

endmodule