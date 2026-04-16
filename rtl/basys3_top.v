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
    output wire [15:0] led,
    // Seven Segment Display
    output wire [6:0] seg,
    output wire dp,
    output wire [3:0] an
);

    wire clk;
    wire rst_n;

    // The Basys3 board actually has a 100MHz oscillator on W5, not 12MHz.
    // We must divide the clock to avoid timing violations and fix the delay length.
    // Divide by 8: 100MHz / 8 = 12.5MHz.
    reg [2:0] clk_div = 3'b000;
    always @(posedge clk_12m) begin
        clk_div <= clk_div + 1'b1;
    end
    
    // Use BUFG to route the divided clock to the global clock network
    BUFG bufg_inst (
        .I(clk_div[2]),
        .O(clk)
    );

    // Reset signal - active low inside modules
    // rst_btn is active high (button pressed = reset)
    reg rst_sync0, rst_sync1;
    always @(posedge clk) begin
        rst_sync0 <= rst_btn;
        rst_sync1 <= rst_sync0;
    end
    assign rst_n = !rst_sync1;

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
        .ext_interrupt(1'b0), // Tie off external interrupt for now
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
        .tx_data(host_data_out[7:0]), // 发送原始的 8-bit ASCII 数据
        .uart_tx(uart_tx),
        .tx_done(tx_done)
    );

    // LED control - running light + error indication
    reg [15:0] led_reg;
    reg [31:0] led_counter;
    reg [3:0] error_code;
    reg host_write_seen;

    // Error detection: if host_write_enable pulses too fast or unexpected, set error
    // Simple watchdog: if no host_write_enable for ~2 seconds, assume hang
    reg [31:0] watchdog_counter;
    reg watchdog_expired;
    
    // Seven segment register
    reg [3:0] sevenseg_digit;

    always @(posedge clk) begin
        if (!rst_n) begin
            led_counter <= 32'd0;
            led_reg <= 16'b0000000000000001;  // Start with LSB on
            error_code <= 4'd0;
            watchdog_counter <= 32'd0;
            watchdog_expired <= 1'b0;
            sevenseg_digit <= 4'd0;
            host_write_seen <= 1'b0;
        end else begin
            // Watchdog: count cycles, reset on host_write_enable
            if (host_write_enable) begin
                watchdog_counter <= 32'd0;
                watchdog_expired <= 1'b0;
                sevenseg_digit <= host_data_out[3:0];
                host_write_seen <= ~host_write_seen;
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
                // Normal: rotate left (running light)
                // Watchdog expired no longer freezes LED, only sets error state if needed
                led_reg <= {led_reg[14:0], led_reg[15]};
            end
        end
    end

    // Seven segment decoding (active low)
    reg [6:0] seg_out;
    always @(*) begin
        case (sevenseg_digit)
            4'd0: seg_out = 7'b1000000; // 0
            4'd1: seg_out = 7'b1111001; // 1
            4'd2: seg_out = 7'b0100100; // 2
            4'd3: seg_out = 7'b0110000; // 3
            4'd4: seg_out = 7'b0011001; // 4
            4'd5: seg_out = 7'b0010010; // 5
            4'd6: seg_out = 7'b0000010; // 6
            4'd7: seg_out = 7'b1111000; // 7
            4'd8: seg_out = 7'b0000000; // 8
            4'd9: seg_out = 7'b0010000; // 9
            4'hA: seg_out = 7'b0001000; // A
            4'hB: seg_out = 7'b0000011; // b
            4'hC: seg_out = 7'b1000110; // C
            4'hD: seg_out = 7'b0100001; // d
            4'hE: seg_out = 7'b0000110; // E
            4'hF: seg_out = 7'b0001110; // F
            default: seg_out = 7'b1111111; // Off
        endcase
    end

    assign seg = seg_out;
    assign dp = 1'b1; // Decimal point off
    assign an = 4'b1110; // Only rightmost digit enabled (active low)

    assign led = {host_write_seen, ~uart_tx, ~uart_rx, led_reg[12:0]};

endmodule
