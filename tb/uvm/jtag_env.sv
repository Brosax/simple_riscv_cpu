// ============================================================================
// JTAG Environment (uvm_env)
// 顶层验证环境：组合 agent 和 scoreboard
// ============================================================================
`ifndef JTAG_ENV_SV
`define JTAG_ENV_SV

class jtag_env extends uvm_env;

    `uvm_component_utils(jtag_env)

    jtag_agent      agent;
    jtag_scoreboard scoreboard;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent      = jtag_agent::type_id::create("agent", this);
        scoreboard = jtag_scoreboard::type_id::create("scoreboard", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        // 将 agent 的 analysis port 连到 scoreboard 的 export
        agent.ap.connect(scoreboard.analysis_export);
    endfunction

endclass : jtag_env

`endif // JTAG_ENV_SV
