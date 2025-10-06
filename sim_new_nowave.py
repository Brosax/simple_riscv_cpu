import sys
import subprocess
import os

# --- Configuration ---
DEFAULT_TEST = "test/isa/hex/rv32ui-p-simple.hex"
SIM_VVP = "tb_riscv_core.vvp"
TEST_PROGRAM_FILE = "test_program.txt"

def main():
    """Main function to run the simulation."""
    # 1. Select test file
    if len(sys.argv) > 1:
        test_hex = sys.argv[1]
    else:
        print(f"No test file provided. Using default: {DEFAULT_TEST}")
        test_hex = DEFAULT_TEST

    if not os.path.exists(test_hex):
        print(f"Error: Test file not found at '{test_hex}'")
        sys.exit(1)

    # 2. Compile RTL
    print("--- Compiling RTL ---")
    compile_process = subprocess.run(["python", "compile_rtl.py"], capture_output=True, text=True)
    if compile_process.returncode != 0:
        print("RTL compilation failed!")
        print(compile_process.stdout)
        print(compile_process.stderr)
        sys.exit(1)
    print(compile_process.stdout)

    # 3. Prepare test program file for the simulation
    print(f"--- Preparing test program: {test_hex} ---")
    try:
        with open(TEST_PROGRAM_FILE, "w") as f:
            f.write(test_hex)
    except IOError as e:
        print(f"Error writing to {TEST_PROGRAM_FILE}: {e}")
        sys.exit(1)

    # 4. Run simulation
    print(f"--- Running simulation for {os.path.basename(test_hex)} ---")
    vvp_cmd = ["vvp", SIM_VVP]
    try:
        process = subprocess.run(vvp_cmd, timeout=20, capture_output=True, text=True)
        print("--- Simulation Output ---")
        print(process.stdout)
        if process.stderr:
            print("--- Simulation Error ---")
            print(process.stderr)
        print("--- Simulation Finished ---")

    except subprocess.TimeoutExpired:
        print("!!! Fail, vvp exec timeout after 20 seconds !!!")
        sys.exit(1)
    except FileNotFoundError:
        print(f"Error: '{SIM_VVP}' not found. Compilation might have failed.")
        sys.exit(1)

if __name__ == '__main__':
    main()
