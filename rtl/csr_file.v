module csr_file (
    input wire clk,
    input wire rst,

    // Instruction Decode / Execution Interface
    input wire [11:0] csr_addr,
    input wire [31:0] csr_wdata,
    input wire csr_we,           // Only true when instruction commits
    output reg [31:0] csr_rdata,

    // Interrupt signals from CLINT/PLIC
    input wire timer_irq,  // MTIP
    input wire ext_irq,    // MEIP

    // Trap handling interface
    input wire trap_trigger,      // Asserted when taking an exception/interrupt
    input wire [31:0] trap_pc,    // PC of the instruction that faulted, or next instruction for interrupts
    input wire [31:0] trap_cause, // Exception/Interrupt cause (e.g., 0x80000007 for timer)
    input wire mret_trigger,      // Asserted when executing MRET

    // Outputs to core control
    output wire [31:0] mtvec_out, // Address to jump to on trap
    output wire [31:0] mepc_out,  // Address to return to on MRET
    output wire mstatus_mie,      // Global interrupt enable
    output wire mie_mtie,         // Timer interrupt enable
    output wire mie_meie,         // External interrupt enable
    output wire mip_mtip,         // Timer interrupt pending
    output wire mip_meip          // External interrupt pending
);

    // CSR Registers (M-mode)
    // mstatus (Machine Status) - specifically MIE (bit 3) and MPIE (bit 7)
    reg [31:0] mstatus;
    // mie (Machine Interrupt Enable) - MTIE (bit 7), MEIE (bit 11)
    reg [31:0] mie;
    // mtvec (Machine Trap-Vector Base-Address)
    reg [31:0] mtvec;
    // mepc (Machine Exception Program Counter)
    reg [31:0] mepc;
    // mcause (Machine Cause)
    reg [31:0] mcause;

    // mip (Machine Interrupt Pending) - read-only for software, updated by hardware
    // MTIP (bit 7) mapped to timer_irq, MEIP (bit 11) mapped to ext_irq
    wire [31:0] mip = {20'b0, ext_irq, 3'b0, timer_irq, 7'b0};

    // Expose outputs
    assign mtvec_out = mtvec;
    assign mepc_out = mepc;
    assign mstatus_mie = mstatus[3];
    assign mie_mtie = mie[7];
    assign mie_meie = mie[11];
    assign mip_mtip = timer_irq;
    assign mip_meip = ext_irq;

    // Address map
    localparam CSR_MSTATUS = 12'h300;
    localparam CSR_MIE     = 12'h304;
    localparam CSR_MTVEC   = 12'h305;
    localparam CSR_MEPC    = 12'h341;
    localparam CSR_MCAUSE  = 12'h342;
    localparam CSR_MIP     = 12'h344;

    // CSR Read
    always @(*) begin
        case (csr_addr)
            CSR_MSTATUS: csr_rdata = mstatus;
            CSR_MIE:     csr_rdata = mie;
            CSR_MTVEC:   csr_rdata = mtvec;
            CSR_MEPC:    csr_rdata = mepc;
            CSR_MCAUSE:  csr_rdata = mcause;
            CSR_MIP:     csr_rdata = mip;
            default:     csr_rdata = 32'b0;
        endcase
    end

    // CSR Write and Trap Handling
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mstatus <= 32'b0;
            mie     <= 32'b0;
            mtvec   <= 32'b0;
            mepc    <= 32'b0;
            mcause  <= 32'b0;
        end else if (trap_trigger) begin
            // Hardware trap taking: save PC to MEPC, Cause to MCAUSE
            // Disable global interrupts (MIE=0) and save previous MIE to MPIE
            mepc <= trap_pc;
            mcause <= trap_cause;
            mstatus[7] <= mstatus[3]; // MPIE = MIE
            mstatus[3] <= 1'b0;       // MIE = 0
        end else if (mret_trigger) begin
            // Hardware trap return (MRET)
            // Restore MIE from MPIE, set MPIE to 1
            mstatus[3] <= mstatus[7]; // MIE = MPIE
            mstatus[7] <= 1'b1;       // MPIE = 1
        end else if (csr_we) begin
            // Software CSR write
            case (csr_addr)
                CSR_MSTATUS: begin
                    mstatus[3] <= csr_wdata[3]; // MIE
                    mstatus[7] <= csr_wdata[7]; // MPIE
                end
                CSR_MIE: begin
                    mie[7]  <= csr_wdata[7];  // MTIE
                    mie[11] <= csr_wdata[11]; // MEIE
                end
                CSR_MTVEC:   mtvec  <= csr_wdata;
                CSR_MEPC:    mepc   <= csr_wdata;
                CSR_MCAUSE:  mcause <= csr_wdata;
                default: ; // Ignored or read-only (MIP)
            endcase
        end
    end

endmodule
