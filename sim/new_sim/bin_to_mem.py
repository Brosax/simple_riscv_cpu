import sys
import os

def convert_bin_to_mem(bin_file, mem_file):
    """Converts a raw binary file to a Verilog-readable hex memory file."""
    try:
        with open(bin_file, 'rb') as f_in:
            with open(mem_file, 'w') as f_out:
                while True:
                    # Read 4 bytes at a time (32-bit instruction)
                    word = f_in.read(4)
                    if not word:
                        break
                    # Ensure the word is 4 bytes long, pad with zeros if not
                    if len(word) < 4:
                        word = word.ljust(4, b'\0')
                    
                    # Convert to a hex string and write to the output file
                    # The RISC-V architecture is little-endian
                    hex_str = "".join(f"{b:02x}" for b in reversed(word))
                    f_out.write(hex_str + '\n')
        #print(f"Successfully converted {bin_file} to {mem_file}")
        return True
    except IOError as e:
        print(f"Error during file conversion: {e}")
        return False

def main():
    if len(sys.argv) != 3:
        print("Usage: python bin_to_mem.py <input_bin_file> <output_mem_file>")
        sys.exit(1)
    
    bin_file = sys.argv[1]
    mem_file = sys.argv[2]

    if not os.path.exists(bin_file):
        print(f"Error: Input file not found: {bin_file}")
        sys.exit(1)

    if not convert_bin_to_mem(bin_file, mem_file):
        sys.exit(1)

if __name__ == '__main__':
    main()

