"""
jtag_agent.py — uvm_agent
组合 JtagDriver、JtagMonitor 和 uvm_sequencer，
对外暴露 uvm_analysis_port（来自 monitor）供 env 连接到 scoreboard。
"""
from pyuvm import uvm_agent, uvm_sequencer, uvm_analysis_port

from jtag_driver  import JtagDriver
from jtag_monitor import JtagMonitor


class JtagAgent(uvm_agent):
    """
    UVM Agent（主动模式）：
      seqr    — 缓冲来自 sequence 的 item
      driver  — 从 sequencer 取 item，驱动 DUT 信号
      monitor — 被动观察总线，广播 transaction
    """

    def build_phase(self):
        self.seqr    = uvm_sequencer("seqr",   self)
        self.driver  = JtagDriver  ("driver",  self)
        self.monitor = JtagMonitor ("monitor", self)
        # 透传 monitor 输出的 analysis port
        self.ap = uvm_analysis_port("ap", self)

    def connect_phase(self):
        # driver ← sequencer：item 流
        self.driver.seq_item_port.connect(self.seqr.seq_item_export)
        # agent.ap ← monitor.ap：事务广播透传
        self.monitor.ap.connect(self.ap)
