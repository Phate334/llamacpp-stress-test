# GPU Stress Test for llama.cpp

A bash script to stress test GPU capability using the [llama.cpp](https://github.com/ggml-org/llama.cpp) `batched-bench` tool.

## Overview

This script implements a GPU stress testing solution that:
- Uses the existing `batched-bench` tool from llama.cpp
- Tests different batch sizes to find GPU critical points
- Outputs results in JSONL format for easy parsing
- Creates meta files with hardware environment information

## Features

- **Environment Variable Configuration**: Uses `BATCHED_BENCH_PATH` and `MODEL_PATH` environment variables
- **Batch Size Testing**: Tests incrementally increasing batch sizes to find GPU limits
- **JSONL Output**: Results saved in JSON Lines format for easy parsing
- **Hardware Meta Data**: Captures system information, GPU details, and test parameters
- **Error Handling**: Graceful handling of failures and timeout conditions
- **Configurable Parameters**: Context length, max batch size, step size, and test duration

## Usage

### Quick Start

```bash
# Set environment variables
export BATCHED_BENCH_PATH="/path/to/llama.cpp/batched-bench"
export MODEL_PATH="/path/to/models"

# Run basic stress test
./gpu_stress_test.sh model.gguf

# Run with custom parameters
./gpu_stress_test.sh -v -c 4096 -m 256 -s 8 -d 60 model.gguf
```

### Command Line Options

- `-v, --verbose`: Enable verbose output
- `-o, --output DIR`: Output directory for results (default: ./results)  
- `-c, --context LENGTH`: Context length (default: 2048)
- `-m, --max-batch SIZE`: Maximum batch size to test (default: 512)
- `-s, --step SIZE`: Step size for batch increments (default: 16)
- `-d, --duration SECONDS`: Test duration per batch size (default: 30)

### Environment Variables

- `BATCHED_BENCH_PATH`: Path to batched-bench executable (required)
- `MODEL_PATH`: Path to model files directory (required)
- `CUDA_VISIBLE_DEVICES`: GPU selection (optional)

## Output Files

The script generates two types of output files:

1. **JSONL Results** (`stress_test_YYYYMMDD_HHMMSS.jsonl`): Line-by-line test results
2. **Meta Information** (`meta_YYYYMMDD_HHMMSS.json`): Hardware info and test parameters

### Example JSONL Output

```jsonl
{"batch_size": 16, "status": "success", "duration": 25.431, "tokens_per_second": 45.2, "prompt_eval_time": 0.125, "eval_time": 2.341, "timestamp": "2024-01-15T10:30:25Z"}
{"batch_size": 32, "status": "success", "duration": 28.156, "tokens_per_second": 42.8, "prompt_eval_time": 0.145, "eval_time": 2.987, "timestamp": "2024-01-15T10:31:15Z"}
{"batch_size": 48, "status": "error", "exit_code": 1, "duration": 15.234, "error": "CUDA out of memory", "timestamp": "2024-01-15T10:32:05Z"}
```

### Example Meta File

```json
{
    "meta": {
        "timestamp": "2024-01-15T10:30:00Z",
        "hostname": "gpu-server-01",
        "test_parameters": {
            "model": "llama-7b.gguf",
            "context_length": 2048,
            "max_batch_size": 512,
            "step_size": 16,
            "test_duration": 30
        },
        "hardware": {
            "cpu": "Intel(R) Xeon(R) CPU E5-2699 v4 @ 2.20GHz",
            "cpu_cores": 44,
            "memory_gb": "128.0",
            "gpu": "NVIDIA GeForce RTX 4090",
            "gpu_memory_gb": "24.0"
        },
        "environment": {
            "batched_bench_path": "/opt/llama.cpp/batched-bench",
            "model_path": "/models",
            "cuda_visible_devices": "all"
        }
    }
}
```

## How It Works

1. **Setup**: Validates environment variables and model file existence
2. **Hardware Detection**: Captures system information and GPU specifications
3. **Batch Testing**: Incrementally tests batch sizes from `STEP_SIZE` to `MAX_BATCH_SIZE`
4. **Critical Point Detection**: Stops after 3 consecutive failures to identify limits
5. **Results Output**: Saves test results in JSONL format and hardware info in JSON

## Examples

### Basic GPU Stress Test

```bash
export BATCHED_BENCH_PATH="/opt/llama.cpp/batched-bench"
export MODEL_PATH="/models"
./gpu_stress_test.sh llama-7b.gguf
```

### High Context Length Testing

```bash
export BATCHED_BENCH_PATH="/opt/llama.cpp/batched-bench"
export MODEL_PATH="/models"
./gpu_stress_test.sh -v -c 4096 -m 256 -s 8 -d 60 llama-13b.gguf
```

### Multi-GPU Testing

```bash
export BATCHED_BENCH_PATH="/opt/llama.cpp/batched-bench"
export MODEL_PATH="/models"
export CUDA_VISIBLE_DEVICES="0,1"
./gpu_stress_test.sh -o gpu_multi_results llama-30b.gguf
```

## Prerequisites

- `batched-bench` executable from llama.cpp
- CUDA-compatible GPU (for GPU testing)
- Model files in GGUF format
- `bc` calculator (for duration calculations)
- `nvidia-smi` (for GPU information collection)

## Installation

```bash
# Clone the repository
git clone https://github.com/Phate334/llamacpp-stress-test.git
cd llamacpp-stress-test

# Make the script executable
chmod +x gpu_stress_test.sh

# Set up environment variables
export BATCHED_BENCH_PATH="/path/to/llama.cpp/batched-bench"
export MODEL_PATH="/path/to/models"
```

## License

This project is licensed under the same license as the repository it belongs to.

## Acknowledgments

- Built using the [llama.cpp](https://github.com/ggml-org/llama.cpp) `batched-bench` tool
- Designed for GPU stress testing and performance validation