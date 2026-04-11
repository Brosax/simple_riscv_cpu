"""
jtag_sequence.py — uvm_sequence
包含三条测试序列：

  JtagIdcodeSeq — 多次读取 IDCODE，验证返回值为 0x00000001
  JtagBypassSeq — BYPASS 测试：全零 + 随机数据，验证一拍延迟透传
  JtagFullSeq   — 综合序列：先跑 IDCODE，再跑 BYPASS
"""
import logging
import random
from pyuvm import uvm_sequence

from jtag_transaction import JtagTransaction, IR_IDCODE, IR_BYPASS

logger = logging.getLogger(__name__)


class JtagIdcodeSeq(uvm_sequence):
    """
    IDCODE 读取序列：
    写入 IR=IDCODE，移出 32 位 DR，期望低 32 位 == 0x00000001。
    """

    def __init__(self, name="idcode_seq", repeat_cnt=3):
        super().__init__(name)
        self.repeat_cnt = repeat_cnt

    async def body(self):
        for i in range(self.repeat_cnt):
            tr = JtagTransaction(f"idcode_tr_{i}")
            tr.ir      = IR_IDCODE
            tr.dr_in   = 0
            tr.dr_bits = 32        # IDCODE 寄存器为 32 位
            await self.start_item(tr)
            await self.finish_item(tr)
            logger.info(f"[IDCODE #{i}] dr_out=0x{tr.dr_out:08x}")


class JtagBypassSeq(uvm_sequence):
    """
    BYPASS 测试序列：
      1. 全零数据：dr_in=0，期望 dr_out=0
      2. 随机数据：验证 TDO 延迟一拍（dr_out == dr_in >> 1）
    """

    def __init__(self, name="bypass_seq"):
        super().__init__(name)

    async def body(self):
        # 测试 1：全零（8 位，观察透传）
        tr0 = JtagTransaction("bypass_zero")
        tr0.ir      = IR_BYPASS
        tr0.dr_in   = 0
        tr0.dr_bits = 8
        await self.start_item(tr0)
        await self.finish_item(tr0)
        logger.info(f"[BYPASS 全零] dr_out=0x{tr0.dr_out:02x}")

        # 测试 2：随机数据（16 位）
        tr1 = JtagTransaction("bypass_rand")
        tr1.ir      = IR_BYPASS
        tr1.dr_in   = random.getrandbits(16)
        tr1.dr_bits = 16
        await self.start_item(tr1)
        await self.finish_item(tr1)
        logger.info(
            f"[BYPASS 随机] dr_in=0x{tr1.dr_in:04x} dr_out=0x{tr1.dr_out:04x}"
        )


class JtagFullSeq(uvm_sequence):
    """
    综合测试序列：依次执行 IDCODE 和 BYPASS 序列。
    """

    def __init__(self, name="full_seq"):
        super().__init__(name)

    async def body(self):
        logger.info("=== 开始 IDCODE 序列 ===")
        idcode_seq = JtagIdcodeSeq("idcode_seq", repeat_cnt=3)
        await idcode_seq.start(self.sequencer)

        logger.info("=== 开始 BYPASS 序列 ===")
        bypass_seq = JtagBypassSeq("bypass_seq")
        await bypass_seq.start(self.sequencer)

        logger.info("=== 综合序列完成 ===")
