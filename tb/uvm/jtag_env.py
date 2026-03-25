"""
jtag_env.py — UVMEnv
顶层验证环境：组合 JtagAgent 和 JtagScoreboard，
并将 agent 的 analysis port 连接到 scoreboard 的 analysis export。
"""
from pyuvm import UVMEnv

from jtag_agent      import JtagAgent
from jtag_scoreboard import JtagScoreboard


class JtagEnv(UVMEnv):
    """
    UVM 验证环境：
      agent      → 负责驱动和监控
      scoreboard → 负责结果检查
    """

    def build_phase(self):
        self.agent      = JtagAgent     ("agent",      self)
        self.scoreboard = JtagScoreboard("scoreboard", self)

    def connect_phase(self):
        # monitor 的事务通过 agent.ap → scoreboard.analysis_export
        self.agent.ap.connect(self.scoreboard.analysis_export)
