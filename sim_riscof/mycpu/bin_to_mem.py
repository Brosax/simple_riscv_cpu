
import sys
import struct

def bin_to_mem(input_file, output_file):
    """
    Converts a binary file to a hexadecimal memory file for Verilog's $readmemh.
    """
    try:
        with open(input_file, 'rb') as f_in, open(output_file, 'w') as f_out:
            while True:
                word = f_in.read(4)
                if not word:
                    break
                # Ensure the word is 4 bytes long, padding with zeros if necessary
                if len(word) < 4:
                    word = word.ljust(4, b'\x00')
                
                val = struct.unpack('<I', word)[0]
                f_out.write(f'{val:08x}\n')
    except IOError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python bin_to_mem.py <input_binary_file> <output_mem_file>")
        sys.exit(1)
    
    bin_to_mem(sys.argv[1], sys.argv[2])
