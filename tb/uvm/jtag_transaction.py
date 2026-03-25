"""
jtag_transaction.py — uvm_sequence_item
表示一次完整的 JTAG 操作：写 IR 指令寄存器 + 移位 DR 数据寄存器
"""
from pyuvm import uvm_sequence_item


# JTAG 指令常量（与 jtag_tap.v 保持一致）
IR_IDCODE = 0b00001   # 读取芯片 ID
IR_BYPASS = 0b11111   # 旁路模式（1 位透传）
IR_DBGACC = 0b10110   # 调试寄存器访问
IR_DBGRST = 0b11010   # 调试复位


class JtagTransaction(uvm_sequence_item):
    """
    一笔 JTAG 事务：包含要写入的 IR 指令和 DR 数据，
    以及从 TDO 采样回来的 DR 输出。
    """

    def __init__(self, name="jtag_tr"):
        super().__init__(name)
        # 要写入的 IR 指令（5 位）
        self.ir: int = IR_IDCODE
        # 要移入 DR 的数据（LSB first）
        self.dr_in: int = 0
        # 从 TDO 移出的 DR 数据（采样结果）
        self.dr_out: int = 0
        # DR 有效位宽（IDCODE=32, BYPASS=1..N, DBGACC=48）
        self.dr_bits: int = 32

    def __str__(self):
        ir_name = {
            IR_IDCODE: "IDCODE",
            IR_BYPASS: "BYPASS",
            IR_DBGACC: "DBGACC",
            IR_DBGRST: "DBGRST",
        }.get(self.ir, f"IR=0x{self.ir:02x}")
        return (
            f"JtagTransaction({ir_name} "
            f"dr_in=0x{self.dr_in:012x} "
            f"dr_out=0x{self.dr_out:012x} "
            f"bits={self.dr_bits})"
        )
