"""
jtag_test.py — uvm_test + cocotb 入口
顶层测试类：创建 JtagEnv，启动 JtagFullSeq 综合测试序列。
cocotb 的 @cocotb.test() 装饰器作为仿真入口，触发 UVM 运行。
"""
import cocotb
from pyuvm import uvm_test, ConfigDB, uvm_root

from jtag_env      import JtagEnv
from jtag_sequence import JtagFullSeq


class JtagTest(uvm_test):
    """
    UVM Test：
      1. build_phase — 创建验证环境
      2. run_phase   — 启动测试序列，完成后 drop_objection 结束仿真
    """

    def build_phase(self):
        self.env = JtagEnv("env", self)

    async def run_phase(self):
        self.raise_objection()
        self.logger.info("=== JTAG pyUVM Testbench 开始 ===")

        seq = JtagFullSeq("full_seq")
        # 将序列启动在 env.agent.seqr 上
        await seq.start(self.env.agent.seqr)

        self.logger.info("=== JTAG pyUVM Testbench 结束 ===")
        self.drop_objection()


# --------------------------------------------------------------------------
# cocotb 入口：仿真启动时调用此函数
# --------------------------------------------------------------------------
@cocotb.test()
async def run_test(dut):
    """
    cocotb test 入口：
      1. 将 DUT handle 存入 ConfigDB，供所有 UVM 组件通过
         ConfigDB().get(self, "", "DUT") 获取
      2. 调用 uvm_root().run_test() 启动 UVM 框架（依次执行所有 phase）
    """
    ConfigDB().set(None, "*", "DUT", dut)
    await uvm_root().run_test("JtagTest")
