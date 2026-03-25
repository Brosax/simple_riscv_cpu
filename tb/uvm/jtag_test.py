"""
jtag_test.py — UVMTest + cocotb 入口
顶层测试类：创建 JtagEnv，启动 JtagFullSeq 综合测试序列。
cocotb 的 @cocotb.test() 装饰器作为仿真入口，触发 UVM 运行。
"""
import cocotb
from pyuvm import UVMTest, ConfigDB, uvm_root

from jtag_env      import JtagEnv
from jtag_sequence import JtagFullSeq


class JtagTest(UVMTest):
    """
    UVM Test：
      1. build_phase  — 创建验证环境
      2. run_phase    — 启动测试序列，完成后撤销 objection 结束仿真
    """

    def build_phase(self):
        self.env = JtagEnv("env", self)

    async def run_phase(self):
        self.raise_objection()
        self.logger.info("=== JTAG pyUVM Testbench 开始 ===")

        seq = JtagFullSeq("full_seq")
        await seq.start(self.env.agent.seqr)

        self.logger.info("=== JTAG pyUVM Testbench 结束 ===")
        self.drop_objection()


# --------------------------------------------------------------------------
# cocotb 入口：当 iverilog 启动仿真时，此函数被调用
# --------------------------------------------------------------------------
@cocotb.test()
async def run_test(dut):
    """
    cocotb test 入口：
      1. 将 DUT handle 注册到 ConfigDB，供所有 UVM 组件使用
      2. 调用 uvm_root().run_test() 启动 UVM 框架
    """
    # 将 DUT handle 存入全局配置数据库
    ConfigDB().set(None, "*", "DUT", dut)
    # 启动 UVM 测试（会依次执行所有 phase）
    await uvm_root().run_test("JtagTest")
