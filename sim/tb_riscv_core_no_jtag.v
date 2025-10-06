`timescale 1 ns / 1 ps

`include "defines.v"


`define TEST_PROG  1


// testbench module
module tb_riscv_core_no_jtag;

    reg clk;
    reg rst;


    always #10 clk = ~clk;     // 50MHz

    wire[`RegBus] x3 = tinyriscv_soc_top_0.u_tinyriscv.u_regs.regs[3];
    wire[`RegBus] x26 = tinyriscv_soc_top_0.u_tinyriscv.u_regs.regs[26];
    wire[`RegBus] x27 = tinyriscv_soc_top_0.u_tinyriscv.u_regs.regs[27];

    wire[31:0] ex_end_flag = tinyriscv_soc_top_0.u_ram._ram[4];
    wire[31:0] begin_signature = tinyriscv_soc_top_0.u_ram._ram[2];
    wire[31:0] end_signature = tinyriscv_soc_top_0.u_ram._ram[3];

    integer r;
    integer fd;

    initial begin
        clk = 0;
        rst = `RstEnable;
        $display("test running...");
        #40
        rst = `RstDisable;
        #200

        wait(ex_end_flag == 32'h1);  // wait sim end

        fd = $fopen(`OUTPUT);   // The value of OUTPUT is defined on the command line
        for (r = begin_signature; r < end_signature; r = r + 4) begin
            $fdisplay(fd, "%x", tinyriscv_soc_top_0.u_rom._rom[r[31:2]]);
        end
        $fclose(fd);

        $finish;
    end

    // sim timeout
    initial begin
        #500000
        $display("Time Out.");
        $finish;
    end

    // read mem data
    initial begin
        $readmemh ("inst.data", tinyriscv_soc_top_0.u_rom._rom);
    end

    // generate wave file, used by gtkwave
    initial begin
        $dumpfile("tb_riscv_core_no_jtag.vcd");
        $dumpvars(0, tb_riscv_core_no_jtag);
    end

    tinyriscv_soc_top tinyriscv_soc_top_0(
        .clk(clk),
        .rst(rst),
        .uart_debug_pin(1'b0)
    );

endmodule
