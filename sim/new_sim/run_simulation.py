import sys
import subprocess
import os

def main():
    """Runs a single simulation after converting a .bin file."""
    if len(sys.argv) < 2:
        print("Usage: python run_simulation.py <path_to_bin_file>")
        sys.exit(1)

    # --- Setup Paths ---
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
    test_bin = os.path.abspath(sys.argv[1])
    
    # The output memory file that the testbench will load
    inst_mem_file = os.path.join(project_root, 'inst.mem')
    
    sim_vvp = os.path.join(project_root, 'tb_riscv_core_new.vvp')
    compile_script = os.path.join(os.path.dirname(__file__), 'compile_rtl.py')
    converter_script = os.path.join(os.path.dirname(__file__), 'bin_to_mem.py')

    # --- Convert .bin to .mem ---
    print(f"--- Converting {os.path.basename(test_bin)} to {os.path.basename(inst_mem_file)} ---")
    converter_cmd = ["python", converter_script, test_bin, inst_mem_file]
    convert_process = subprocess.run(converter_cmd, capture_output=True, text=True)
    if convert_process.returncode != 0:
        print("Binary to memory conversion failed!")
        print(convert_process.stdout)
        print(convert_process.stderr)
        return False # Indicate failure

    # --- Compile RTL (if needed, could be done once) ---
    # print("--- Compiling RTL ---")
    # compile_process = subprocess.run(["python", compile_script], capture_output=True, text=True)
    # if compile_process.returncode != 0:
    #     print("RTL compilation failed!")
    #     print(compile_process.stdout)
    #     print(compile_process.stderr)
    #     return False # Indicate failure
    # print(compile_process.stdout)

    # --- Run simulation ---
    print(f"--- Running simulation for {os.path.basename(test_bin)} ---")
    vvp_cmd = ["vvp", sim_vvp]
    try:
        # Run from project root to ensure inst.mem and log files are found there
        process = subprocess.run(vvp_cmd, timeout=30, check=True, text=True, cwd=project_root)
        # print("--- Simulation Finished ---")
        return True # Indicate success
    except subprocess.TimeoutExpired as e:
        print("!!! FAIL: Python script timed out after 30 seconds !!!")
        print("--- VVP STDOUT ---")
        print(e.stdout)
        print("--- VVP STDERR ---")
        print(e.stderr)
        print("------------------")
        return False # Indicate failure
    except subprocess.CalledProcessError as e:
        print(f"!!! FAIL: Simulation exited with a non-zero status code !!!")
        print("--- VVP STDOUT ---")
        print(e.stdout)
        print("--- VVP STDERR ---")
        print(e.stderr)
        print("------------------")
        return False # Indicate failure
    except FileNotFoundError:
        print(f"Error: '{sim_vvp}' not found. You may need to run the compile script first.")
        return False # Indicate failure

if __name__ == '__main__':
    # The main test runner (test_all_isa.py) will compile once.
    # This script assumes the .vvp file exists.
    if not main():
        sys.exit(1)
    sys.exit(0)