module basys3_top(
    input wire clk_12m,
    input wire rst_btn,   // CPU reset button (active high), mapped to CPU reset
    // Debug/JTAG inputs (hardcoded for FPGA standalone)
    input wire debug_stall,
    input wire [4:0] debug_reg_addr,
    input wire debug_reg_read,
    input wire debug_reg_write,
    input wire [31:0] debug_reg_wdata,
    input wire debug_mem_read,
    input wire [31:0] debug_mem_addr,
    input wire debug_mem_write,
    input wire [31:0] debug_mem_wdata,
    input wire [3:0] debug_mem_wstrb,
    // UART
    output wire uart_tx,
    input wire uart_rx,
    // LED
    output wire [15:0] led
);

    wire clk;
    wire rst_n;

    // Reset signal - active low inside modules
    // rst_btn is active high (button pressed = reset)
    reg rst_sync0, rst_sync1;
    always @(posedge clk) begin
        rst_sync0 <= rst_btn;
        rst_sync1 <= rst_sync0;
    end
    assign rst_n = !rst_sync1;

    // Clock - use 12MHz directly (no PLL for minimal design)
    assign clk = clk_12m;

    // Debug signals - tie off for FPGA standalone
    wire [31:0] debug_reg_rdata;
    wire [31:0] debug_mem_rdata;

    // host_write_enable pulse from CPU (tohost write)
    wire host_write_enable;
    wire [31:0] host_data_out;

    // UART TX signals
    wire tx_enable;
    wire [7:0] tx_data;
    wire tx_done;

    // Instantiate RISC-V core
    riscv_core #(
    ) riscv_core_inst (
        .clk(clk),
        .rst(rst_sync1),
        .timer_interrupt(),
        .gpio_pins(),
        .host_write_enable(host_write_enable),
        .host_data_out(host_data_out),
        .debug_stall(1'b0),
        .debug_stall_status(),
        .debug_pc_value(),
        .debug_reg_addr(5'd0),
        .debug_reg_read(1'b0),
        .debug_reg_write(1'b0),
        .debug_reg_wdata(32'd0),
        .debug_reg_rdata(),
        .debug_mem_read(1'b0),
        .debug_mem_addr(32'd0),
        .debug_mem_write(1'b0),
        .debug_mem_wdata(32'd0),
        .debug_mem_wstrb(4'd0),
        .debug_mem_rdata()
    );

    // Instantiate UART TX
    uart_tx uart_tx_inst (
        .clk(clk),
        .rst_n(rst_n),
        .tx_enable(host_write_enable),
        .tx_data(host_data_out[7:0]),
        .uart_tx(uart_tx),
        .tx_done(tx_done)
    );

    // LED control - running light + error indication
    reg [15:0] led_reg;
    reg [31:0] led_counter;
    reg [3:0] error_code;

    // Error detection: if host_write_enable pulses too fast or unexpected, set error
    // Simple watchdog: if no host_write_enable for ~2 seconds, assume hang
    reg [31:0] watchdog_counter;
    reg watchdog_expired;

    always @(posedge clk) begin
        if (!rst_n) begin
            led_counter <= 32'd0;
            led_reg <= 16'b0000000000000001;  // Start with LSB on
            error_code <= 4'd0;
            watchdog_counter <= 32'd0;
            watchdog_expired <= 1'b0;
        end else begin
            // Watchdog: count cycles, reset on host_write_enable
            if (host_write_enable) begin
                watchdog_counter <= 32'd0;
                watchdog_expired <= 1'b0;
            end else if (watchdog_counter < 32'd24_000_000) begin  // ~2s @ 12MHz
                watchdog_counter <= watchdog_counter + 1'b1;
                watchdog_expired <= 1'b0;
            end else begin
                watchdog_expired <= 1'b1;
            end

            // LED shift register: shift every ~500ms @ 12MHz = 6_000_000 cycles
            if (led_counter < 32'd6_000_000) begin
                led_counter <= led_counter + 1'b1;
            end else begin
                led_counter <= 32'd0;
                if (!watchdog_expired) begin
                    // Normal: rotate left (running light)
                    led_reg <= {led_reg[14:0], led_reg[15]};
                end
                // If watchdog expired, freeze LEDs (error indication)
            end
        end
    end

    assign led = led_reg;

endmodule
