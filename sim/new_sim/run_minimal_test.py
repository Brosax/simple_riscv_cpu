import subprocess
import sys
import os
import glob

def main():
    """Compiles and runs the minimal testbench to check for simulator crashes."""
    
    # --- Setup Paths ---
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
    sim_vvp = os.path.join(project_root, 'tb_minimal.vvp')
    tb_file = os.path.join(project_root, 'sim', 'tb_minimal.v')
    rtl_dir = os.path.join(project_root, 'rtl')

    # --- Compile ---
    print("--- Compiling minimal testbench ---")
    iverilog_cmd = [
        "iverilog",
        "-g2012",
        "-o",
        sim_vvp,
        tb_file,
    ]
    rtl_files = glob.glob(os.path.join(rtl_dir, '*.v'))
    iverilog_cmd.extend(rtl_files)

    compile_process = subprocess.run(iverilog_cmd, capture_output=True, text=True)
    if compile_process.returncode != 0:
        print("!!! FAIL: Compilation failed !!!")
        print(compile_process.stdout)
        print(compile_process.stderr)
        sys.exit(1)
    print("Compilation successful.")

    # --- Run ---
    print("\n--- Running minimal simulation ---")
    vvp_cmd = ["vvp", sim_vvp]
    try:
        process = subprocess.run(vvp_cmd, timeout=10, check=True, capture_output=True, text=True, cwd=project_root)
        print("--- Simulation Output ---")
        print(process.stdout)
        print("--- Simulation Errors ---")
        print(process.stderr)
        print("\n---> SUCCESS: Minimal test ran without crashing the simulator.")

    except subprocess.TimeoutExpired as e:
        print("!!! FAIL: Simulation timed out !!!")
        print(e.stdout)
        print(e.stderr)
    except subprocess.CalledProcessError as e:
        print("!!! FAIL: Simulation exited with an error !!!")
        print(e.stdout)
        print(e.stderr)
    except FileNotFoundError:
        print(f"Error: '{sim_vvp}' not found.")

if __name__ == '__main__':
    main()
