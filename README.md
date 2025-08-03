# llama.cpp Stress Test Helper

This repository provides a bash script wrapper for llama.cpp's `batched-bench` tool, designed to simplify benchmarking and stress testing while ensuring consistent output and metadata collection.

## Overview

The `bench-helper.sh` script automates the execution of `llama-batched-bench` with the following features:

- **JSONL Output**: Results are saved in JSON Lines format for easy parsing and analysis.
- **Environment Metadata**: Captures system information, GPU details, and test parameters.
- **Error Handling**: Ensures graceful handling of missing executables or invalid configurations.
- **Output Management**: Saves results and environment metadata in the `results/` directory.

## Features

- **Automatic Metadata Collection**: Captures CPU, GPU, and memory information.
- **JSONL Output Enforcement**: Forces output format to JSONL for consistency.
- **Flexible Argument Handling**: Supports all `llama-batched-bench` parameters.
- **Environment Information**: Saves environment details in a separate JSON file.

## Usage

### Basic Execution

Run the script with `llama-batched-bench` arguments:

```bash
./bench-helper.sh -m model.gguf -c 2048 -b 512 -ub 256 -ngl 99
```

### Advanced Benchmarking

Include additional parameters for detailed testing:

```bash
./bench-helper.sh -m model.gguf -c 4096 -b 1024 -ub 512 -ngl 99 \
    -npp 128,256,512 -ntg 128,256 -npl 1,2,4,8,16,32
```

### Output Directory

Specify a custom output directory:

```bash
./bench-helper.sh -o /path/to/output -m model.gguf -c 2048 -b 512
```

## Output Files

The script generates the following files in the `results/` directory:

1. **Benchmark Results** (`output.jsonl`): Contains line-by-line test results.
2. **Environment Metadata** (`environment.json`): Includes system information and test parameters.

### Example JSONL Output

```jsonl
{"n_kv_max": 2048, "n_batch": 512, "n_ubatch": 512, "flash_attn": 0, "is_pp_shared": 0, "n_gpu_layers": 99, "n_threads": 8, "n_threads_batch": 8, "pp": 128, "tg": 128, "pl": 1, "n_kv": 256, "t_pp": 0.233810, "speed_pp": 547.453064, "t_tg": 3.503684, "speed_tg": 36.532974, "t": 3.737494, "speed": 68.495094}
```

### Example Environment Metadata

```json
{
  "timestamp": "2025-08-03T10:30:00Z",
  "bench_executable": "/app/llama-batched-bench",
  "bench_arguments": ["-m", "model.gguf", "-c", "2048", "-b", "512"],
  "gpu_info": {
    "name": "NVIDIA GeForce RTX 4090",
    "memory_total_mb": 24576
  },
  "cpu_info": {
    "model": "Intel(R) Xeon(R) CPU E5-2699 v4 @ 2.20GHz",
    "cores": 44
  },
  "memory_info": {
    "total_mb": 128000,
    "available_mb": 120000
  }
}
```

## Prerequisites

- `llama-batched-bench` executable from llama.cpp
- CUDA-compatible GPU
- Model files in GGUF format
- `nvidia-smi` for GPU information collection

## Installation

```bash
# Clone the repository
git clone https://github.com/Phate334/llamacpp-stress-test.git
cd llamacpp-stress-test

# Make the script executable
chmod +x bench-helper.sh
```

## License

This project is licensed under the same license as the repository it belongs to.

## Acknowledgments

- Built as a wrapper for [llama.cpp](https://github.com/ggml-org/llama.cpp) `batched-bench` tool.
- Designed for GPU stress testing and performance validation.
