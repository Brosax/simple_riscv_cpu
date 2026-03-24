import sys
import os
import subprocess
import filecmp

# --- Configuration ---
# RISC-V GCC 工具链前缀 (需要通过 WSL 调用)
TOOL_PREFIX = "riscv32-unknown-elf-"
# 编译时使用的 ISA 和 ABI
ARCH_FLAGS = "-march=rv32i -mabi=ilp32"

# 项目内工具和文件的路径
# 注意：路径分隔符使用了 /，以便在 WSL 和 Windows 中都能更好地工作
COMPILER_SCRIPT = "example_file/compile_rtl.py"
BIN_TO_MEM_SCRIPT = "example_file/BinToMem_CLI.py"
SIM_OUTPUT_VVP = "tb_riscv_core.vvp"  # 假设编译脚本输出这个文件
INST_MEM_FILE = "inst.mem"
SIGNATURE_FILE = "signature.log"

# --- Helper Functions ---

def list_ref_files(path):
    """找出指定目录下的所有 .reference_output 文件"""
    files = []
    # 确保路径存在
    if not os.path.isdir(path):
        print(f"!!! Error: Reference directory not found at '{path}'")
        return files
    
    list_dir = os.walk(path)
    for maindir, _, all_file in list_dir:
        for filename in all_file:
            apath = os.path.join(maindir, filename)
            # 在这个项目中，dump 文件就是参考文件
            if apath.endswith('.dump'):
                files.append(apath)
    return files

def get_reference_file(s_file):
    """根据 .S 源文件找到对应的 .dump 参考文件"""
    file_path, file_name = os.path.split(s_file)
    # 从 "I-ADD-01.S" 中获取 "I-ADD-01"
    prefix = os.path.splitext(file_name)[0]

    # 根据 .S 文件的路径推断参考文件的目录
    # 例如: .../rv32i/src -> .../rv32i/references
    ref_dir = os.path.abspath(os.path.join(file_path, '..', 'references'))
    
    files = list_ref_files(ref_dir)
    if not files:
        return None

    # 根据文件名找到对应的 .dump 文件
    # riscv-tests 的 dump 文件名通常是 <test_name>.dump
    # 例如 I-ADD-01.S -> rv32ui-p-add.dump (需要更智能的匹配)
    # 简单起见，我们先用 test name 来匹配
    # 注意：实际的 .dump 文件名可能与 .S 文件名不完全对应，这里做了简化处理
    # 一个更健壮的方案需要解析 riscv-tests 的 Makefile
    
    # 我们先假设 dump 文件名和 .S 文件名有直接关系
    # 例如 add.S -> rv32ui-p-add.dump
    # 为了演示，我们先做一个简单的映射
    test_name_in_dump = file_name.replace('.S','').lower() # add
    if 'rv32ui-p-' + test_name_in_dump + '.dump' in [os.path.basename(f) for f in files]:
         for f in files:
             if os.path.basename(f) == 'rv32ui-p-' + test_name_in_dump + '.dump':
                 return f

    print(f"--- Warning: Could not find a direct match for '{prefix}'. Please verify manually. ---")
    return None


# --- Main Execution ---

def main():
    if len(sys.argv) < 2:
        print("Usage: python run_single_test.py <path_to_s_file>")
        print("Example: python run_single_test.py example_file/riscv-compliance/riscv-test-suite/rv32i/src/I-ADD-01.S")
        return 1

    s_file = sys.argv[1]
    if not os.path.exists(s_file):
        print(f"!!! Error: Source file not found at '{s_file}'")
        return 1
        
    test_name = os.path.splitext(os.path.basename(s_file))[0]
    elf_file = f"{test_name}.elf"

    print("=================================================")
    print(f"STEP 0: Compiling .S to ELF via WSL")
    print("=================================================")
    # 需要 riscv-tests 环境中的链接脚本和宏
    # 我们需要构造一个复杂的 GCC 命令
    # riscv-tests/env/p/link.ld
    # riscv-tests/macros/scalar
    # CFLAGS = -march=rv32i -mabi=ilp32 -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles
    # INCLUDES = -I../macros/scalar -I../env/p
    # LINKER_SCRIPT = -T../env/p/link.ld
    # CMD: riscv32-unknown-elf-gcc ${CFLAGS} ${INCLUDES} ${LINKER_SCRIPT} -o <elf_file> <s_file>
    # 由于路径复杂性，我们先跳过这一步，并假设 ELF 文件已存在
    # 在实际使用中，需要先在 riscv-tests 目录中 make isa
    print("--- SKIPPED (manual step required) ---")
    print("--- Please run 'wsl make -C internal-tools/riscv-tests isa' first ---")
    
    # 假设ELF文件在 internal-tools/riscv-tests/isa/rv32ui-p-add
    elf_file_path = f"internal-tools/riscv-tests/isa/rv32ui-p-{test_name.lower()}"
    if not os.path.exists(elf_file_path):
        print(f"!!! Error: ELF file '{elf_file_path}' not found.")
        print("Please compile the riscv-tests suite first by running 'wsl make -C internal-tools/riscv-tests isa'")
        return 1

    print("\n=================================================")
    print(f"STEP 1: Converting ELF to '{INST_MEM_FILE}'")
    print("=================================================")
    cmd_b2m = f"python {BIN_TO_MEM_SCRIPT} {elf_file_path} {INST_MEM_FILE}"
    print(f"Executing: {cmd_b2m}")
    try:
        subprocess.run(cmd_b2m, shell=True, check=True)
        print("-> Conversion successful.")
    except subprocess.CalledProcessError as e:
        print(f"!!! FAIL: Binary to Memory conversion failed. Error: {e}")
        return 1

    print("\n=================================================")
    print("STEP 2: Compiling RTL")
    print("=================================================")
    cmd_compile = f"python {COMPILER_SCRIPT}"
    print(f"Executing: {cmd_compile}")
    try:
        # 假设 compile_rtl.py 会将编译产物放在正确的位置
        subprocess.run(cmd_compile, shell=True, check=True)
        print("-> RTL compilation successful.")
    except subprocess.CalledProcessError as e:
        print(f"!!! FAIL: RTL Compilation failed. Error: {e}")
        return 1

    print("\n=================================================")
    print(f"STEP 3: Running Simulation ('{SIM_OUTPUT_VVP}')")
    print("=================================================")
    if not os.path.exists(SIM_OUTPUT_VVP):
        print(f"!!! FAIL: Simulation executable '{SIM_OUTPUT_VVP}' not found after compilation.")
        return 1
        
    vvp_cmd = ["vvp", SIM_OUTPUT_VVP]
    print(f"Executing: {' '.join(vvp_cmd)}")
    try:
        with open('run.log', 'w') as logfile:
            process = subprocess.Popen(vvp_cmd, stdout=logfile, stderr=subprocess.STDOUT)
            process.wait(timeout=10) # 10秒超时
        print(f"-> Simulation finished. Signature generated at '{SIGNATURE_FILE}'.")
    except subprocess.TimeoutExpired:
        process.kill()
        print("!!! FAIL: Simulation timed out after 10 seconds.")
        return 1
    except Exception as e:
        print(f"!!! FAIL: Simulation failed with an exception: {e}")
        return 1

    print("\n=================================================")
    print("STEP 4: Comparing Signatures")
    print("=================================================")
    if not os.path.exists(SIGNATURE_FILE):
        print(f"!!! FAIL: Signature file '{SIGNATURE_FILE}' was not generated by the simulation.")
        return 1

    # 在 riscv-tests 中，dump 文件在 isa 目录，和 elf 文件在一起
    ref_file = elf_file_path + ".dump"

    if os.path.exists(ref_file):
        print(f"Comparing '{SIGNATURE_FILE}' with '{ref_file}'")
        if filecmp.cmp(SIGNATURE_FILE, ref_file, shallow=False):
            print("\n##################")
            print("###  PASS  ###")
            print("##################")
        else:
            print("\n!!!!!!!!!!!!!!!!!!!!!!!!!!")
            print("!!!  FAIL: Signature Mismatch  !!!")
            print("!!!!!!!!!!!!!!!!!!!!!!!!!!")
            # 可以在这里打印两个文件的差异
            with open(SIGNATURE_FILE) as f1, open(ref_file) as f2:
                sig_lines = f1.readlines()
                ref_lines = f2.readlines()
                print(f"Got {len(sig_lines)} lines, Expected {len(ref_lines)} lines.")
                # 打印前5行不同之处
                count = 0
                for i in range(min(len(sig_lines), len(ref_lines))):
                    if sig_lines[i] != ref_lines[i]:
                        print(f"Line {i+1}: Got '{sig_lines[i].strip()}' != Exp '{ref_lines[i].strip()}'")
                        count += 1
                        if count >= 5:
                            break
    else:
        print(f"--- Warning: Reference file '{ref_file}' not found. Please check result manually. ---")
        print(f"--- Signature output is available at '{SIGNATURE_FILE}' ---")

    return 0

if __name__ == '__main__':
    sys.exit(main())
