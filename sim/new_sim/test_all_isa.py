import os
import sys
import glob
import subprocess
import filecmp

def convert_hex_to_signature(hex_file_path):
    """Converts a space-separated hex file to a list of 32-bit hex values."""
    with open(hex_file_path, 'r') as f:
        lines = f.readlines()
    
    hex_values = []
    for line in lines:
        hex_values.extend(line.strip().split())

    # The hex file is a stream of bytes, we need to group them into 32-bit words
    # and reverse the byte order (little-endian to big-endian).
    signature = []
    for i in range(0, len(hex_values), 4):
        word = "".join(reversed(hex_values[i:i+4]))
        signature.append(word)
    return signature



def main():
    """Main function to run all ISA regression tests using .bin files."""
    
    # --- Setup Paths ---
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
    test_dir = os.path.join(project_root, 'test', 'isa', 'generated')
    hex_dir = os.path.join(project_root, 'test', 'isa', 'hex')
    
    simulation_script = os.path.join(os.path.dirname(__file__), 'run_simulation.py')
    compile_script = os.path.join(os.path.dirname(__file__), 'compile_rtl.py')
    
    signature_log = os.path.join(project_root, 'signature.log')
    inst_mem_file = os.path.join(project_root, 'inst.mem')

    # --- Find all test files ---
    # We now look for .bin files
    test_files = [os.path.join(test_dir, 'rv32ui-p-add.bin')]

    if not test_files:
        print("No .bin test files found. Check test directory and patterns.")
        sys.exit(1)

    # --- Compile RTL once before starting ---
    print("=================================================")
    print("COMPILING RTL (ONCE)")
    print("=================================================")
    compile_process = subprocess.run(["python", compile_script], capture_output=True, text=True)
    if compile_process.returncode != 0:
        print("RTL compilation failed! Aborting tests.")
        print(compile_process.stdout)
        print(compile_process.stderr)
        sys.exit(1)
    print(compile_process.stdout)

    # --- Counters ---
    passed_count = 0
    failed_count = 0

    # --- Run all tests ---
    print("=================================================")
    print("STARTING RISC-V ISA REGRESSION (.bin files)")
    print("=================================================")

    for test_bin in sorted(test_files):
        test_name = os.path.basename(test_bin)
        print(f"\n--- Running Test: {test_name} ---")

        # --- Run Simulation ---
        cmd = ["python", simulation_script, test_bin]
        sim_process = subprocess.run(cmd, capture_output=True, text=True)

        if sim_process.returncode != 0:
            print(f"!!! FAIL: Simulation script failed for {test_name} !!!")
            print(sim_process.stdout)
            print(sim_process.stderr)
            failed_count += 1
            # Optional: stop on first fail
            # break 
            continue

        # --- Check Result ---
        ref_hex_file = os.path.join(hex_dir, test_name.replace('.bin', '.hex'))

        if not os.path.exists(signature_log):
            print(f"!!! FAIL: signature.log not generated for {test_name}. Simulation likely failed to complete.")
            print("--- Simulation STDOUT ---")
            print(sim_process.stdout)
            print("--- Simulation STDERR ---")
            print(sim_process.stderr)
            print("-------------------------")
            failed_count += 1
        elif not os.path.exists(ref_hex_file):
            print(f"!!! WARNING: Reference hex file not found for {ref_hex_file}. Cannot verify result.")
        else:
            # Convert the reference hex file to a signature list
            ref_signature = convert_hex_to_signature(ref_hex_file)
            
            # Read the generated signature
            with open(signature_log, 'r') as f:
                generated_signature = [line.strip() for line in f.readlines()]

            if ref_signature == generated_signature:
                print(f"---> PASS: Signature matches for {test_name}")
                passed_count += 1
            else:
                print(f"!!! FAIL: Signature mismatch for {test_name} !!!")
                # Print the differences
                print("--- Generated Signature ---")
                print("\n".join(generated_signature))
                print("--- Reference Signature ---")
                print("\n".join(ref_signature))
                print("---------------------------")
                failed_count += 1
    # --- Cleanup ---
    if os.path.exists(signature_log):
        os.remove(signature_log)
    if os.path.exists(inst_mem_file):
        os.remove(inst_mem_file)

    # --- Summary ---
    total_tests = len(test_files)
    print("\n=================================================")
    print("REGRESSION SUMMARY")
    print("=================================================")
    print(f"TOTAL TESTS: {total_tests}")
    print(f"PASSED: {passed_count}")
    print(f"FAILED: {failed_count}")
    print("-------------------------------------------------")
    if failed_count > 0:
        print("OVERALL STATUS: FAIL")
        sys.exit(1)
    else:
        print("OVERALL STATUS: PASS")
        sys.exit(0)

if __name__ == '__main__':
    main()