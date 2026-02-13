## Download PCM
```
cd tools
git clone --recursive https://github.com/intel/pcm.git
```

## Download stream
```
cd tools
mkdir stream
cd stream
wget https://www.cs.virginia.edu/stream/FTP/Code/stream.c
```

## Run on slurm
```
sbatch stream_fio.sh
```