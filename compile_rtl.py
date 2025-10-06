import subprocess
import sys

def main():
    """Compiles the RISC-V core RTL and testbench."""
    iverilog_cmd = [
        "iverilog",
        "-g2012",
        "-o",
        "tb_riscv_core.vvp",
        "sim/tb_riscv_core.v",
    ]
    
    # Add all Verilog files from the rtl directory
    import glob
    rtl_files = glob.glob("rtl/*.v")
    iverilog_cmd.extend(rtl_files)

    print(f"Running command: {' '.join(iverilog_cmd)}")
    
    try:
        process = subprocess.run(iverilog_cmd, check=True, capture_output=True, text=True)
        print("Compilation successful.")
        print(process.stdout)
    except subprocess.CalledProcessError as e:
        print("Compilation failed.")
        print(e.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
