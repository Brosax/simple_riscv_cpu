// ============================================================================
// JTAG TAP (Test Access Port) Controller
// IEEE 1149.1 compatible, minimal RISC-V debug support
// ============================================================================
module jtag_tap (
    input  wire       tck,
    input  wire       tms,
    input  wire       tdi,
    output reg        tdo,
    input  wire       trst_n,

    output reg        debug_req,
    output reg        debug_write,
    output reg        debug_type,
    output reg [12:0] debug_addr,
    output reg [31:0] debug_wdata,
    input  wire[31:0] debug_rdata,
    output reg        debug_update
);

    // -------------------------------------------------------------------------
    // TAP State Machine (IEEE 1149.1)
    // -------------------------------------------------------------------------
    localparam S_RESET = 0, S_RTI = 1, S_SEL_DR = 2, S_CAP_DR = 3,
               S_SHIFT_DR = 4, S_EXIT1_DR = 5, S_PAUSE_DR = 6,
               S_EXIT2_DR = 7, S_UPD_DR = 8, S_SEL_IR = 9,
               S_CAP_IR = 10, S_SHIFT_IR = 11, S_EXIT1_IR = 12,
               S_PAUSE_IR = 13, S_EXIT2_IR = 14, S_UPD_IR = 15;

    reg [3:0] state, next_state;

    always @(negedge tck or negedge trst_n) begin
        if (!trst_n)
            state <= S_RESET;
        else
            state <= next_state;
    end

    always @(*) begin
        case (state)
            S_RESET:     next_state = tms ? S_RESET : S_RTI;
            S_RTI:       next_state = tms ? S_SEL_DR : S_RTI;
            S_SEL_DR:    next_state = tms ? S_SEL_IR : S_CAP_DR;
            S_CAP_DR:    next_state = tms ? S_EXIT1_DR : S_SHIFT_DR;
            S_SHIFT_DR:  next_state = tms ? S_EXIT1_DR : S_SHIFT_DR;
            S_EXIT1_DR:  next_state = tms ? S_UPD_DR : S_PAUSE_DR;
            S_PAUSE_DR:  next_state = tms ? S_EXIT2_DR : S_PAUSE_DR;
            S_EXIT2_DR:  next_state = tms ? S_UPD_DR : S_SHIFT_DR;
            S_UPD_DR:    next_state = tms ? S_SEL_DR : S_RTI;
            S_SEL_IR:    next_state = tms ? S_RESET : S_CAP_IR;
            S_CAP_IR:    next_state = tms ? S_EXIT1_IR : S_SHIFT_IR;
            S_SHIFT_IR:  next_state = tms ? S_EXIT1_IR : S_SHIFT_IR;
            S_EXIT1_IR:  next_state = tms ? S_UPD_IR : S_PAUSE_IR;
            S_PAUSE_IR:  next_state = tms ? S_EXIT2_IR : S_PAUSE_IR;
            S_EXIT2_IR:  next_state = tms ? S_UPD_IR : S_SHIFT_IR;
            S_UPD_IR:    next_state = tms ? S_SEL_DR : S_RTI;
            default:     next_state = S_RESET;
        endcase
    end

    // -------------------------------------------------------------------------
    // Instruction Register
    // ir is updated at negedge TCK.  Capture-IR=0b00001, Shift-IR, Update-IR.
    // -------------------------------------------------------------------------
    localparam IR_IDCODE = 5'b00001, IR_BYPASS = 5'b11111,
               IR_DBGACC = 5'b10110, IR_DBGRST = 5'b11010,
               IR_CAP    = 5'b00001;

    reg [4:0] ir;

    always @(negedge tck or negedge trst_n) begin
        if (!trst_n)
            ir <= 5'b0;
        else if (state == S_CAP_IR)
            ir <= IR_CAP;
        else if (state == S_SHIFT_IR)
            ir <= {tdi, ir[4:1]};
    end

    // -------------------------------------------------------------------------
    // BYPASS
    // -------------------------------------------------------------------------
    reg bypass_reg;

    always @(negedge tck or negedge trst_n) begin
        if (!trst_n)
            bypass_reg <= 1'b0;
        else if (state == S_CAP_DR)
            bypass_reg <= 1'b0;
        else if (state == S_SHIFT_DR && ir == IR_BYPASS)
            bypass_reg <= tdi;
    end

    // -------------------------------------------------------------------------
    // Debug Data Register — 48 bits, LSB-first shift
    //   dr[47]   = op       (1=write, 0=read)
    //   dr[46]   = type     (1=memory, 0=register)
    //   dr[45:32] = addr_hi (upper 14 bits of 13-bit addr → actually [44:32])
    //   dr[31:0] = data
    // Capture: at CAPTURE_DR, loads IDCODE[31:0] into dr[31:0] when ir=IDCODE.
    // -------------------------------------------------------------------------
    localparam IDCODE_VAL = 32'h00000001;

    reg [47:0] dr;

    always @(negedge tck or negedge trst_n) begin
        if (!trst_n) begin
            dr <= 48'b0;
        end else if (state == S_CAP_DR) begin
            // When IR=IDCODE, capture IDCODE into lower 32 bits; upper bits=0
            if (ir == IR_IDCODE) begin
                dr[31:0]  <= IDCODE_VAL;
                dr[47:32] <= 16'b0;
            end else begin
                // Other instructions: capture external debug data
                dr[31:0]  <= debug_rdata;
                dr[47:32] <= 16'b0;
            end
        end else if (state == S_SHIFT_DR) begin
            // Shift LSB-first: {tdi, dr[47:1]}
            dr <= {tdi, dr[47:1]};
        end
    end

    // -------------------------------------------------------------------------
    // Update debug outputs at UPDATE-DR
    // -------------------------------------------------------------------------
    wire is_debug = (ir == IR_DBGACC) || (ir == IR_DBGRST);

    always @(negedge tck or negedge trst_n) begin
        if (!trst_n) begin
            debug_req    <= 1'b0;
            debug_write  <= 1'b0;
            debug_type   <= 1'b0;
            debug_addr   <= 13'b0;
            debug_wdata  <= 32'b0;
            debug_update <= 1'b0;
        end else if (state == S_UPD_DR) begin
            debug_req    <= is_debug;
            debug_write  <= dr[47];
            debug_type   <= dr[46];
            debug_addr   <= dr[44:32];
            debug_wdata  <= dr[31:0];
            debug_update <= is_debug;
        end else begin
            debug_req    <= 1'b0;
            debug_update <= 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // TDO: drive only in SHIFT states
    // -------------------------------------------------------------------------
    always @(*) begin
        if (state == S_SHIFT_DR) begin
            if (ir == IR_BYPASS)
                tdo = bypass_reg;
            else
                tdo = dr[0];
        end else if (state == S_SHIFT_IR) begin
            tdo = ir[0];
        end else begin
            tdo = 1'b0;
        end
    end

endmodule
