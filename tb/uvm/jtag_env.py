"""
jtag_env.py — uvm_env
顶层验证环境：组合 JtagAgent 和 JtagScoreboard，
将 agent 的 analysis port 连接到 scoreboard 的 analysis export。
"""
from pyuvm import uvm_env

from jtag_agent      import JtagAgent
from jtag_scoreboard import JtagScoreboard


class JtagEnv(uvm_env):
    """
    UVM 验证环境：
      agent      — 驱动和监控 JTAG 总线
      scoreboard — 验证输出结果
    """

    def build_phase(self):
        self.agent      = JtagAgent     ("agent",      self)
        self.scoreboard = JtagScoreboard("scoreboard", self)

    def connect_phase(self):
        # monitor 事务路径：agent.ap → scoreboard.analysis_export
        self.agent.ap.connect(self.scoreboard.analysis_export)
