import subprocess
import time
import os

class GPURunner:
    def __init__(self, path):
        self.path = path
        self.processes = []  # Changed to a list to hold multiple processes
        self.output_path = None
        self.cores = []
        self.files = []      # Keep track of open file handles to close them later

    def init(self, output_path, cores, mem_numa, opts):
        self.output_path = output_path
        self.cores = cores

    def set_instsize(self, size): pass
    def set_pattern(self, pat): pass
    def set_writefrac(self, frac): pass
    def set_hugepages(self, enable): pass

    def run(self, duration):
        print(f"Starting {len(self.cores)} GPU Stress instances on cores {self.cores}...")
        
        for i, core in enumerate(self.cores):
            # 1. Create a unique output file for each core (e.g., gpu.txt-1, gpu.txt-2)
            # We assume output_path is something like ".../result.gpu"
            core_out_path = f"{self.output_path}-core{core}"
            f = open(core_out_path, 'w')
            self.files.append(f)

            # 2. Build the command pinned to THIS specific core
            cmd = ['numactl', f'--physcpubind={core}', self.path, str(duration)]
            
            # 3. Launch and store the process
            p = subprocess.Popen(cmd, stdout=f, stderr=subprocess.STDOUT)
            self.processes.append(p)

    def wait(self):
        # Wait for ALL processes to finish
        for p in self.processes:
            p.wait()
        
        # Close all file handles
        for f in self.files:
            f.close()