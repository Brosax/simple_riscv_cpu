import subprocess
import sys
import os
import glob

def main():
    """Compiles the RISC-V core RTL and testbench."""
    
    # Paths relative to the project root
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
    
    sim_vvp = os.path.join(project_root, 'tb_riscv_core_new.vvp')
    tb_file = os.path.join(project_root, 'sim', 'tb_riscv_core_new.v')
    rtl_dir = os.path.join(project_root, 'rtl')

    iverilog_cmd = [
        "iverilog",
        "-g2012",
        "-o",
        sim_vvp,
        tb_file,
    ]
    
    # Add all Verilog files from the rtl directory
    rtl_files = glob.glob(os.path.join(rtl_dir, '*.v'))
    iverilog_cmd.extend(rtl_files)

    print(f"Running command: {' '.join(iverilog_cmd)}")
    
    try:
        # Execute from the project root for correct file paths in iverilog
        process = subprocess.run(iverilog_cmd, check=True, capture_output=True, text=True, cwd=project_root)
        print("Compilation successful.")
        print(process.stdout)
    except subprocess.CalledProcessError as e:
        print("Compilation failed.")
        print(e.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
