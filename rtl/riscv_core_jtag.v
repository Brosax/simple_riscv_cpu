// ============================================================================
// riscv_core_jtag: riscv_core + JTAG TAP debug interface
// ============================================================================
module riscv_core_jtag (
    input  wire       clk,
    input  wire       rst,

    // ----- Standard CPU interface (for top-level integration) ---------------
    output wire        timer_interrupt,
    inout  wire [7:0] gpio_pins,
    output wire        host_write_enable,
    output wire [31:0] host_data_out,

    // ----- JTAG signals -------------------------------------------------------
    input  wire       jtag_tck,
    input  wire       jtag_tms,
    input  wire       jtag_tdi,
    output wire        jtag_tdo,
    input  wire       jtag_trst_n      // async reset for TAP (active-low)
);

    // ----- JTAG TAP -----------------------------------------------------------
    wire        tap_debug_req;
    wire        tap_debug_write;
    wire        tap_debug_type;
    wire [12:0] tap_debug_addr;
    wire [31:0] tap_debug_wdata;
    wire [31:0] tap_debug_rdata;
    wire        tap_debug_update;

    jtag_tap u_jtag_tap (
        .tck           (jtag_tck),
        .tms           (jtag_tms),
        .tdi           (jtag_tdi),
        .tdo           (jtag_tdo),
        .trst_n        (jtag_trst_n),
        .debug_req     (tap_debug_req),
        .debug_write   (tap_debug_write),
        .debug_type    (tap_debug_type),
        .debug_addr    (tap_debug_addr),
        .debug_wdata   (tap_debug_wdata),
        .debug_rdata   (tap_debug_rdata),
        .debug_update  (tap_debug_update)
    );

    // ----- JTAG request handler -----------------------------------------------
    // Decodes debug register address and performs register/memory access.
    //
    // Debug register address mapping (addr[6:0]):
    //   0x00-0x1F  → GPR x0-x31
    // Special addresses (addr[12:7]):
    //   7'h40 (0x20) → PC[31:0]  (read=PC, write=next PC target)
    //   7'h48 (0x21) → STATUS    (bit[0]=halted)
    //   7'h50 (0x22) → RESUME     (write=1 to clear stall & resume CPU)
    //
    // Memory access (debug_type=1):
    //   addr[12:2] = 10-bit byte address [31:2] into data memory space

    wire        is_reg_access  = (tap_debug_addr[12:7] < 7'h40);
    wire        is_pc_access   = (tap_debug_addr[12:7] == 7'h40);
    wire        is_status_access = (tap_debug_addr[12:7] == 7'h41);
    wire        is_resume_access = (tap_debug_addr[12:7] == 7'h42);
    wire        is_mem_access  = tap_debug_type;

    // Internal stall signal: set when JTAG initiates a debug access
    reg         dbg_stall;
    always @(posedge clk or posedge rst) begin
        if (rst)      dbg_stall <= 1'b0;
        else if (!jtag_trst_n) dbg_stall <= 1'b0;
        else if (tap_debug_update && (is_reg_access || is_pc_access || is_resume_access))
                         dbg_stall <= 1'b0;   // resume clears stall
        else if (tap_debug_update && (is_mem_access || is_status_access))
                         dbg_stall <= tap_debug_write; // write sets stall
    end

    // Read-back data mux: what the TAP sees as debug_rdata
    reg  [31:0] tap_rdata;
    always @(*) begin
        if      (is_reg_access)   tap_rdata = dbg_reg_rdata;
        else if (is_pc_access)    tap_rdata = dbg_pc_value + 32'd4;  // PC already advanced
        else if (is_status_access) tap_rdata = {31'b0, dbg_stall};
        else if (is_mem_access)   tap_rdata = dbg_mem_rdata;
        else                       tap_rdata = 32'b0;
    end

    // ----- CPU debug ports ----------------------------------------------------
    // Register access
    assign dbg_reg_addr     = is_reg_access ? tap_debug_addr[4:0] : 5'b0;
    assign dbg_reg_read      = tap_debug_update && is_reg_access && !tap_debug_write;
    assign dbg_reg_write     = tap_debug_update && is_reg_access &&  tap_debug_write;
    assign dbg_reg_wdata     = tap_debug_wdata;

    wire   [4:0]  dbg_reg_addr;
    wire          dbg_reg_read;
    wire          dbg_reg_write;
    wire   [31:0] dbg_reg_wdata;
    wire   [31:0] dbg_reg_rdata;

    // Memory access (memory address is addr[12:2] as a byte offset)
    assign dbg_mem_read      = tap_debug_update && is_mem_access && !tap_debug_write;
    assign dbg_mem_write      = tap_debug_update && is_mem_access &&  tap_debug_write;
    assign dbg_mem_addr       = {20'b0, tap_debug_addr[12:2]};  // 10-bit → 32-bit byte addr
    assign dbg_mem_wdata     = tap_debug_wdata;
    // Byte enable: write=1 → all 4 bytes; write=0 → all 4 bytes for read
    assign dbg_mem_wstrb      = {2'b11, 2'b11};

    wire   [31:0] dbg_mem_addr;
    wire   [31:0] dbg_mem_wdata;
    wire   [1:0]  dbg_mem_wstrb;

    // PC access: read PC (returns current PC), write PC (load new PC)
    // We approximate this by letting the stall handle it; actual PC write
    // would require a dedicated debug PC write port.
    wire   [31:0] dbg_pc_value;

    // ----- CPU stall ---------------------------------------------------------
    // Stall CPU whenever JTAG wants to read or write a register/memory.
    // For register reads (write=0): stall for one cycle so the read returns
    // correct data without the CPU overwriting it mid-access.
    wire   debug_stall = dbg_stall;

    // ----- RISC-V Core -------------------------------------------------------
    riscv_core u_core (
        .clk               (clk),
        .rst               (rst),
        .timer_interrupt   (timer_interrupt),
        .gpio_pins         (gpio_pins),
        .host_write_enable (host_write_enable),
        .host_data_out     (host_data_out),
        .debug_stall       (debug_stall),
        .debug_stall_status(),
        .debug_pc_value    (dbg_pc_value),
        .debug_reg_addr    (dbg_reg_addr),
        .debug_reg_read    (dbg_reg_read),
        .debug_reg_write   (dbg_reg_write),
        .debug_reg_wdata   (dbg_reg_wdata),
        .debug_reg_rdata   (dbg_reg_rdata),
        .debug_mem_read    (dbg_mem_read),
        .debug_mem_addr    (dbg_mem_addr),
        .debug_mem_write   (dbg_mem_write),
        .debug_mem_wdata   (dbg_mem_wdata),
        .debug_mem_wstrb   (dbg_mem_wstrb),
        .debug_mem_rdata   (dbg_mem_rdata)
    );

    wire [31:0] dbg_mem_rdata;

endmodule
