// ============================================================================
// JTAG SystemVerilog Interface
// 封装 TCK/TMS/TDI/TDO/TRST_N 信号，供 UVM 组件共享
// ============================================================================
interface jtag_if (input logic tck);

    logic tms;
    logic tdi;
    logic tdo;
    logic trst_n;

    // 调试端口（连接到 DUT 的 debug_* 信号）
    logic        debug_req;
    logic        debug_write;
    logic        debug_type;
    logic [12:0] debug_addr;
    logic [31:0] debug_wdata;
    logic [31:0] debug_rdata;
    logic        debug_update;

    // Driver clocking block：在 TCK 下降沿驱动信号
    clocking driver_cb @(negedge tck);
        output tms;
        output tdi;
        output trst_n;
        input  tdo;
    endclocking

    // Monitor clocking block：在 TCK 上升沿采样
    clocking monitor_cb @(posedge tck);
        input tms;
        input tdi;
        input tdo;
        input trst_n;
    endclocking

    // Driver 和 Monitor 使用的 modport
    modport driver_mp  (clocking driver_cb,  input tck);
    modport monitor_mp (clocking monitor_cb, input tck);

endinterface : jtag_if
