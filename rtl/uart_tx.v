module uart_tx(
    input wire clk,
    input wire rst_n,
    input wire tx_enable,
    input wire [7:0] tx_data,
    output reg uart_tx,
    output reg tx_done
);

    // 115200 bps @ 12MHz
    // baud_div = 12_000_000 / 115200 ≈ 104
    localparam BAUD_DIV = 104;

    localparam IDLE  = 3'd0;
    localparam START = 3'd1;
    localparam BIT0  = 3'd2;
    localparam BIT1  = 3'd3;
    localparam BIT2  = 3'd4;
    localparam BIT3  = 3'd5;
    localparam BIT4  = 3'd6;
    localparam BIT5  = 3'd7;
    localparam BIT6  = 3'd8;
    localparam BIT7  = 3'd9;
    localparam STOP  = 3'd10;
    localparam DONE  = 3'd11;

    reg [3:0] state;
    reg [15:0] baud_counter;
    reg [7:0] tx_shift_reg;
    wire baud_tick;

    assign baud_tick = (baud_counter == BAUD_DIV - 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            baud_counter <= 16'd0;
            tx_done <= 1'b0;
            uart_tx <= 1'b1;  // Mark (idle)
        end else begin
            case (state)
                IDLE: begin
                    tx_done <= 1'b0;
                    uart_tx <= 1'b1;
                    baud_counter <= 16'd0;
                    if (tx_enable) begin
                        tx_shift_reg <= tx_data;
                        state <= START;
                    end
                end

                START: begin
                    uart_tx <= 1'b0;  // Start bit
                    if (baud_tick) begin
                        baud_counter <= 16'd0;
                        state <= BIT0;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                BIT0: begin
                    uart_tx <= tx_shift_reg[0];
                    if (baud_tick) begin
                        baud_counter <= 16'd0;
                        state <= BIT1;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                BIT1: begin
                    uart_tx <= tx_shift_reg[1];
                    if (baud_tick) begin
                        baud_counter <= 16'd0;
                        state <= BIT2;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                BIT2: begin
                    uart_tx <= tx_shift_reg[2];
                    if (baud_tick) begin
                        baud_counter <= 16'd0;
                        state <= BIT3;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                BIT3: begin
                    uart_tx <= tx_shift_reg[3];
                    if (baud_tick) begin
                        baud_counter <= 16'd0;
                        state <= BIT4;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                BIT4: begin
                    uart_tx <= tx_shift_reg[4];
                    if (baud_tick) begin
                        baud_counter <= 16'd0;
                        state <= BIT5;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                BIT5: begin
                    uart_tx <= tx_shift_reg[5];
                    if (baud_tick) begin
                        baud_counter <= 16'd0;
                        state <= BIT6;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                BIT6: begin
                    uart_tx <= tx_shift_reg[6];
                    if (baud_tick) begin
                        baud_counter <= 16'd0;
                        state <= BIT7;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                BIT7: begin
                    uart_tx <= tx_shift_reg[7];
                    if (baud_tick) begin
                        baud_counter <= 16'd0;
                        state <= STOP;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                STOP: begin
                    uart_tx <= 1'b1;  // Stop bit
                    if (baud_tick) begin
                        baud_counter <= 16'd0;
                        state <= DONE;
                    end else begin
                        baud_counter <= baud_counter + 1'b1;
                    end
                end

                DONE: begin
                    tx_done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
