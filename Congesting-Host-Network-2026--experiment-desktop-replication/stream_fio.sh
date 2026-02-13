#!/bin/bash
#SBATCH -A MSC001
#SBATCH --job-name=mio-icelake
#SBATCH --output=result_%j.out
#SBATCH --error=error_%j.err
#SBATCH --time=00:10:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --constraint=ICELAKE

module purge

# loading gcc, fio, python, cmake and numactl
module load GCC/14.2.0
module load fio/3.38-GCCcore-14.2.0
module load Python-bundle-PyPI/2025.04-GCCcore-14.2.0
module load numactl/2.0.19-GCCcore-14.2.0
module load CMake/3.31.3-GCCcore-14.2.0

# copying the folder where the job was submitted from 
echo "Copying repository from $SLURM_SUBMIT_DIR to $TMPDIR"
cp -r "$SLURM_SUBMIT_DIR/." "$TMPDIR"
cd "$TMPDIR"

# compiling stream
gcc -O3 -march=icelake-server -fopenmp -DSTREAM_ARRAY_SIZE=80000000 tools/stream/stream.c -o tools/stream/stream

# compiling pcm
mkdir tools/pcm/build
cd tools/pcm/build
cmake ..
make
cd "$TMPDIR"

# creating dummy test files for fio
touch fio_test_1 fio_test_2 fio_test_3 fio_test_4

# create directory to store results
mkdir temp_results

# This Python script detects which cores Slurm gave us
# and writes a valid config.json for just those cores.
python3 -c '
import os, json, shutil

# 1. Get the list of cores Slurm allowed us to use
# This returns something like {10, 12} if Slurm gave us those cores.
allowed_cores = sorted(list(os.sched_getaffinity(0)))
core_str = ",".join(str(c) for c in allowed_cores)

print(f"DEBUG: Slurm assigned us physical cores: {core_str}")

# Find the real location of the FIO binary from the module
fio_executable = shutil.which("fio")
if fio_executable:
    fio_dir = os.path.dirname(fio_executable)  # Get the folder, e.g., /apps/bin
else:
    fio_dir = "fio" # Fallback

# 2. Create the config structure
config = {
    "MLC_PATH": "mlc",
    "PCM_PATH": "tools/pcm/build/bin",
    "STATS_PATH": "temp_results",
    "FIO_PATH": fio_dir,
    "STREAM_PATH": "tools/stream",
    "REDIS_PATH": "redis-server",
    "MEMTIER_PATH": "memtier_benchmark",
    "MMAPBENCH_PATH": "mmapbench",
    "GAPBS_PATH": "gapbs",
    
    # We tell mio these are the ONLY cores that exist
    "NUMA_CORES": [core_str], 
    "NUMA_ORDER": "0",
    
    "SSDS": ["fio_test_1", "fio_test_2", "fio_test_3", "fio_test_4"],
    "SSDScomment": ["Dummy files"],
    "MEM_CHANNELS": [],
    "CHAS": [],
    "IPRS": [],
    "CHA_FREQ": 2400000000,
    "IMC_FREQ": 1463000000
}

# 3. Save it
with open("config.json", "w") as f:
    json.dump(config, f, indent=4)
'

echo "Starting Benchmark on $(hostname) at $(date)"

python3 -m mio c2m-p2m \
  --ant_num_cores 1 \
  --ant_mem_numa 0 \
  --ant stream \
  --ant_writefrac 0 \
  --ant_inst_size 64 \
  --ant_duration 120 \
  --fio \
  --fio_mem_numa 0 \
  --fio_writefrac 0 \
  --fio_iosize $((8*1024*1024)) \
  --fio_iodepth 64 \
  --fio_num_ssds 4 \
  --sync_durations \
  --notouch_prefetch \
  --stats


echo "Benchmark finished. Saving results..."
DEST_DIR="$SLURM_SUBMIT_DIR/results/job_$SLURM_JOB_ID"
mkdir -p "$DEST_DIR"
cp -r temp_results/. "$DEST_DIR/"
cp config.json "$DEST_DIR/"

echo "Results saved to: $DEST_DIR"