
import os
import shutil
import subprocess
import logging
import riscof.utils as utils
from riscof.pluginTemplate import pluginTemplate

logger = logging.getLogger()

class mycpu(pluginTemplate):
    __model__ = "mycpu"
    __version__ = "1.0"

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        config = kwargs.get('config')
        self.dut_exe = ""  # Not a single executable, managed by scripts
        self.num_jobs = str(config['jobs'] if 'jobs' in config else 1)
        self.pluginpath = os.path.abspath(config['pluginpath'])
        self.isa_spec = os.path.abspath(config['ispec'])
        self.platform_spec = os.path.abspath(config['pspec'])
        
        # Get absolute paths to project directories
        self.root_dir = os.path.abspath(os.path.join(self.pluginpath, '..', '..'))
        self.rtl_dir = os.path.join(self.root_dir, 'rtl')
        self.sim_dir = os.path.join(self.root_dir, 'sim')
        self.tb_file = os.path.join(self.sim_dir, 'tb_riscv_core_new.v')

    def initialise(self, suite, work_dir, archtest_env):
        self.work_dir = work_dir
        self.suite_dir = suite
        
        # Path to the compiled VVP file, which will be in the root of the work_dir
        self.vvp_file = os.path.join(self.work_dir, "dut.vvp")

        # Determine XLEN from ISA spec to configure toolchain
        ispec = utils.load_yaml(self.isa_spec)['hart0']
        self.xlen = ('64' if 64 in ispec['supported_xlen'] else '32')

        # Toolchain paths
        self.objcopy_cmd = f"riscv{self.xlen}-unknown-elf-objcopy"
        self.python_cmd = "python3"
        self.bin_to_mem_script = os.path.join(self.pluginpath, "bin_to_mem.py")

    def build(self, isa_yaml, platform_yaml):
        # The build is now ISA-agnostic and happens once.
        # We determine xlen in initialise, which is called before build.
        
        # Check if tools are available
        if shutil.which("iverilog") is None:
            logger.error("iverilog not found. Please check environment setup.")
            raise SystemExit(1)
        if shutil.which(self.objcopy_cmd) is None:
            logger.error(f"{self.objcopy_cmd} not found. Please check environment setup.")
            raise SystemExit(1)
        if shutil.which("vvp") is None:
            logger.error("vvp not found. Please check environment setup.")
            raise SystemExit(1)

        # One-time compilation of the DUT's RTL and testbench
        rtl_files = [os.path.join(self.rtl_dir, f) for f in os.listdir(self.rtl_dir) if f.endswith('.v')]
        
        compile_cmd = [
            "iverilog",
            "-g2012",
            "-o", self.vvp_file,
            self.tb_file
        ] + rtl_files
        
        logger.info(f"Compiling DUT with command: {' '.join(compile_cmd)}")
        
        try:
            res = subprocess.run(compile_cmd, check=True, capture_output=True, text=True)
            logger.info("DUT compilation successful.")
            logger.debug(res.stdout)
        except subprocess.CalledProcessError as e:
            logger.error("DUT compilation failed.")
            logger.error(e.stderr)
            raise SystemExit(1)

    def runTests(self, testList):
        make = utils.makeUtil(makefilePath=os.path.join(self.work_dir, "Makefile." + self.name))
        make.makeCommand = 'make -k -j' + self.num_jobs

        for testname in testList:
            testentry = testList[testname]
            test_dir = testentry['work_dir']
            
            # The framework compiles the test to an ELF file.
            elf_file = os.path.join(test_dir, testname + ".elf")
            bin_file = os.path.join(test_dir, "inst.bin")
            mem_file = os.path.join(test_dir, "inst.mem")

            # Command to convert ELF to a format our testbench can load
            elf_to_mem_cmd = f"{self.objcopy_cmd} -O binary {elf_file} {bin_file} && " \
                             f"{self.python_cmd} {self.bin_to_mem_script} {bin_file} {mem_file}"

            # Command to run the simulation
            # The VVP file is in work_dir, and we run it from the specific test_dir
            sim_cmd = f"vvp {self.vvp_file}"

            # Concatenate all commands that need to be executed within a make-target.
            # We must execute from the test's working directory so vvp can find inst.mem
            execute_cmds = f"cd {test_dir} && {elf_to_mem_cmd} && {sim_cmd}"
            
            make.add_target(execute_cmds, testname)

        make.execute_all(self.work_dir)
