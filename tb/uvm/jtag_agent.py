"""
jtag_agent.py — UVMAgent
组合 JtagDriver、JtagMonitor 和 UVMSequencer，
对外暴露 analysis port（来自 monitor）供 env 连接到 scoreboard。
"""
from pyuvm import UVMAgent, UVMSequencer, UVMAnalysisPort

from jtag_driver  import JtagDriver
from jtag_monitor import JtagMonitor


class JtagAgent(UVMAgent):
    """
    UVM Agent（主动模式）：
      - sequencer：缓冲来自 sequence 的 item
      - driver：从 sequencer 取 item，驱动 DUT 信号
      - monitor：被动观察总线，广播 transaction
    """

    def build_phase(self):
        # 创建子组件
        self.seqr    = UVMSequencer("seqr",    self)
        self.driver  = JtagDriver ("driver",   self)
        self.monitor = JtagMonitor("monitor",  self)
        # analysis port 透传 monitor 输出
        self.ap = UVMAnalysisPort("ap", self)

    def connect_phase(self):
        # driver ← sequencer：item 流
        self.driver.seq_item_port.connect(self.seqr.seq_item_export)
        # agent.ap ← monitor.ap：事务广播
        self.monitor.ap.connect(self.ap)
