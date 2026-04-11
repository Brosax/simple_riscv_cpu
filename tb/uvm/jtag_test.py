"""
jtag_test.py — uvm_test + cocotb 入口
顶层测试类：创建 JtagEnv，启动 JtagFullSeq 综合测试序列。
cocotb 的 @cocotb.test() 装饰器作为仿真入口，触发 UVM 运行。
"""
import cocotb
from pyuvm import uvm_test, ConfigDB, uvm_root

from jtag_env      import JtagEnv
from jtag_sequence import JtagFullSeq

# run_test() 将 DUT handle 存于此，供 build_phase 使用。
# 原因：uvm_root().run_test() 默认 keep_singletons=False，
# 会在启动前清空所有单例（包括 ConfigDB），
# 因此必须在 build_phase 内（singletons 重建后）再写入。
_dut = None


class JtagTest(uvm_test):
    """
    UVM Test：
      1. build_phase — 注册 DUT 并创建验证环境
      2. run_phase   — 启动测试序列，完成后 drop_objection 结束仿真
    """

    def build_phase(self):
        ConfigDB().set(None, "*", "DUT", _dut)
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
      将 DUT handle 存入模块变量，再启动 UVM 框架。
      DUT 的 ConfigDB 注册推迟到 JtagTest.build_phase，
      避免被 run_test 的 singleton 清理覆盖。
    """
    global _dut
    _dut = dut
    await uvm_root().run_test("JtagTest")
