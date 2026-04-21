import re

with open('rtl/riscv_core.v', 'r') as f:
    lines = f.readlines()

out = []
skip = False
for i, line in enumerate(lines):
    if line.strip() == 'input wire ext_interrupt,':
        if any('input wire ext_interrupt,' in l for l in out):
            continue
    if line.strip() == "localparam OPCODE_SYSTEM = 7'b1110011;":
        if any("localparam OPCODE_SYSTEM = 7'b1110011;" in l for l in out):
            continue
    if line.strip() == "assign timer_interrupt = timer_interrupt_internal;":
        if any("assign timer_interrupt = timer_interrupt_internal;" in l for l in out):
            continue
    out.append(line)

content = "".join(out)

# Remove the duplicated system/interrupt logic
# It starts at `// System instruction decode` and goes up to `wire csr_we = is_csr && instruction_done && (funct3[1:0] != 2'b00 || rs1 != 5'b0); // don't write if rs1=0 for RS/RC` or the `real_pc_stall`.
# Since there are multiple copies, let's just use regex to keep the first one.

sys_decode_block = re.findall(r'(\t// System instruction decode.*?\n\n)', content, flags=re.DOTALL)
if len(sys_decode_block) > 1:
    # Keep the first one, replace all occurrences with a placeholder, then put the first one back.
    # Actually, it's easier to just find the duplicates and replace them with empty string.
    # We'll just split on `// System instruction decode`
    parts = content.split('\t// System instruction decode\n')
    # the first part is before the block.
    # the second part is the block.
    # third part is another block... etc
    # Let's be careful. Let's just find the exact string of the first block.
    pass

# A safer approach: I will just overwrite riscv_core.v with a cleaned up version.
