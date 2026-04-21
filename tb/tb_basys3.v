`timescale 1ns / 1ps

module tb_basys3;

    reg clk_12m;
    reg rst_btn;
    wire uart_tx;
    wire uart_rx = 1'b1;
    wire [15:0] led;
    wire [6:0] seg;
    wire dp;
    wire [3:0] an;

    // Provide a dummy BUFG for simulation if needed, or if iverilog supports it
    // iverilog usually complains about BUFG unless we define it
    
    basys3_top uut (
        .clk_12m(clk_12m),
        .rst_btn(rst_btn),
        .debug_stall(1'b0),
        .debug_reg_addr(5'd0),
        .debug_reg_read(1'b0),
        .debug_reg_write(1'b0),
        .debug_reg_wdata(32'd0),
        .debug_mem_read(1'b0),
        .debug_mem_addr(32'd0),
        .debug_mem_write(1'b0),
        .debug_mem_wdata(32'd0),
        .debug_mem_wstrb(4'd0),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        .led(led),
        .seg(seg),
        .dp(dp),
        .an(an)
    );

    initial begin
        clk_12m = 0;
        forever #41.666 clk_12m = ~clk_12m; // ~12MHz
    end

    initial begin
        rst_btn = 1;
        #200;
        rst_btn = 0;
        
        #500000;
        $display("Done waiting.");
        $finish;
    end

    always @(posedge uut.clk) begin
        $display("Time=%0t: PC=%h, INST=%h, STATE=%d, STALL=%b, TRAP=%b, MRET=%b", 
            $time, uut.riscv_core_inst.pc_current, uut.riscv_core_inst.instruction, 
            uut.riscv_core_inst.cpu_state, uut.riscv_core_inst.stall, uut.riscv_core_inst.trap_trigger, uut.riscv_core_inst.mret_trigger);
        if (uut.host_write_enable) begin
            $display("Time=%0t: UART TX triggered with data %h ('%c')", $time, uut.host_data_out, uut.host_data_out);
        end
    end

endmodule

module BUFG (
    input wire I,
    output wire O
);
    assign O = I;
endmodule
