# GPU Stress Test for llama.cpp

A bash script wrapper for llama.cpp's `batched-bench` tool that provides full parameter compatibility while adding JSONL output and metadata collection for analysis.

## Overview

This script provides two modes of operation:
1. **Direct Mode**: Full compatibility with `llama.cpp/tools/batched-bench` parameters
2. **Legacy Stress Test Mode**: Incremental batch size testing (backward compatibility)

Key features:
- **Full Parameter Compatibility**: Supports all `batched-bench` parameters including threading, GPU, and model options
- **JSONL Output**: All results saved in JSON Lines format for easy parsing and analysis
- **Metadata Collection**: Captures system information, GPU details, and test parameters
- **Legacy Compatibility**: Maintains backward compatibility with original stress testing approach

## Features

- **Environment Variable Configuration**: Uses `BATCHED_BENCH_PATH` and `MODEL_PATH` environment variables
- **Full Parameter Pass-through**: All `batched-bench` parameters are supported
- **JSONL Output**: Results saved in JSON Lines format for easy parsing
- **Hardware Meta Data**: Captures system information, GPU details, and test parameters
- **Error Handling**: Graceful handling of failures and timeout conditions
- **Two Operation Modes**: Direct batched-bench execution or legacy stress testing

## Usage

### Direct Mode (Recommended)

Use all original `batched-bench` parameters with automatic JSONL output:

```bash
# Set environment variables
export BATCHED_BENCH_PATH="/path/to/llama.cpp/batched-bench"
export MODEL_PATH="/path/to/models"

# Basic usage with batched-bench parameters
./gpu_stress_test.sh -c 2048 -b 512 -ub 256 -ngl 99 model.gguf

# Advanced benchmarking
./gpu_stress_test.sh -c 4096 -b 1024 -ub 512 -ngl 99 \\
    -npp 128,256,512 -ntg 128,256 -npl 1,2,4,8,16,32 -pps model.gguf

# With threading and GPU options
./gpu_stress_test.sh -c 2048 -b 512 -ngl 99 -t 8 -tb 8 \\
    -fa -mg 0 -sm layer model.gguf
```

### Legacy Stress Test Mode

For backward compatibility with incremental batch size testing:

```bash
# Legacy stress test mode
./gpu_stress_test.sh --stress-test --max-batch 256 --step 16 --duration 60 model.gguf
```

## Supported Parameters

### Original batched-bench Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-m, --model FILE` | Model path | Required |
| `-c, --ctx-size N` | Context size | 2048 |
| `-b, --batch-size N` | Logical batch size | 512 |
| `-ub, --ubatch-size N` | Physical batch size | 512 |
| `-ngl, --n-gpu-layers N` | GPU layers to offload | 0 |
| `-mg, --main-gpu N` | Main GPU device | 0 |
| `-t, --threads N` | Generation threads | auto |
| `-tb, --threads-batch N` | Batch processing threads | auto |
| `-sm, --split-mode MODE` | Split mode (none/layer/row) | default |
| `-ts, --tensor-split N,N` | Tensor split ratios | default |
| `-fa, --flash-attn` | Enable flash attention | false |
| `-npp VALUES` | Prompt tokens per sequence | - |
| `-ntg VALUES` | Tokens to generate per sequence | - |
| `-npl VALUES` | Number of parallel sequences | - |
| `-pps` | Prompt is shared across sequences | false |

### Wrapper-specific Parameters  

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-v, --verbose` | Enable verbose output | false |
| `-o, --output DIR` | Output directory | ./results |
| `--stress-test` | Enable legacy stress test mode | false |
| `--max-batch SIZE` | Max batch size (stress test) | 512 |
| `--step SIZE` | Step size (stress test) | 16 |
| `--duration SECONDS` | Test duration (stress test) | 30 |

### Environment Variables

- `BATCHED_BENCH_PATH`: Path to batched-bench executable (required)
- `MODEL_PATH`: Path to model files directory (required)
- `CUDA_VISIBLE_DEVICES`: GPU selection (optional)

## Output Files

The script generates two types of output files:

1. **JSONL Results** (`batched_bench_YYYYMMDD_HHMMSS.jsonl`): Line-by-line test results
2. **Meta Information** (`meta_YYYYMMDD_HHMMSS.json`): Hardware info and test parameters

### Example JSONL Output (Direct Mode)

```jsonl
{"n_kv_max": 2048, "n_batch": 512, "n_ubatch": 512, "flash_attn": 0, "is_pp_shared": 0, "n_gpu_layers": 99, "n_threads": 8, "n_threads_batch": 8, "pp": 128, "tg": 128, "pl": 1, "n_kv": 256, "t_pp": 0.233810, "speed_pp": 547.453064, "t_tg": 3.503684, "speed_tg": 36.532974, "t": 3.737494, "speed": 68.495094}
{"n_kv_max": 2048, "n_batch": 512, "n_ubatch": 512, "flash_attn": 0, "is_pp_shared": 0, "n_gpu_layers": 99, "n_threads": 8, "n_threads_batch": 8, "pp": 128, "tg": 128, "pl": 2, "n_kv": 512, "t_pp": 0.422602, "speed_pp": 605.770935, "t_tg": 11.106112, "speed_tg": 23.050371, "t": 11.528713, "speed": 44.410854}
```

### Example Meta File

```json
{
    "meta": {
        "timestamp": "2025-01-15T10:30:00Z",
        "hostname": "gpu-server-01",
        "test_parameters": {
            "model": "llama-7b.gguf",
            "context_length": 2048,
            "batch_size": 512,
            "ubatch_size": 512,
            "gpu_layers": 99,
            "flash_attn": true,
            "prompt_shared": false,
            "npp_values": ["128", "256", "512"],
            "ntg_values": ["128", "256"],
            "npl_values": ["1", "2", "4", "8"]
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
            "cuda_visible_devices": "all",
            "batched_bench_command": "/opt/llama.cpp/batched-bench -m /models/llama-7b.gguf -c 2048 -b 512 -ub 512 -ngl 99 -fa --output-format jsonl"
        }
    }
}
```

## Examples

### Basic GPU Testing

```bash
export BATCHED_BENCH_PATH="/opt/llama.cpp/batched-bench"
export MODEL_PATH="/models"
./gpu_stress_test.sh -ngl 99 llama-7b.gguf
```

### High Context Length Testing

```bash
export BATCHED_BENCH_PATH="/opt/llama.cpp/batched-bench"
export MODEL_PATH="/models"
./gpu_stress_test.sh -v -c 4096 -b 1024 -ub 512 -ngl 99 \\
    -npp 256,512,1024 -ntg 256,512 -npl 1,2,4,8 llama-13b.gguf
```

### Multi-GPU Testing

```bash
export BATCHED_BENCH_PATH="/opt/llama.cpp/batched-bench"
export MODEL_PATH="/models"
export CUDA_VISIBLE_DEVICES="0,1"
./gpu_stress_test.sh -o gpu_multi_results -ngl 99 -sm layer -ts 0.6,0.4 llama-30b.gguf
```

### Legacy Stress Testing

```bash
export BATCHED_BENCH_PATH="/opt/llama.cpp/batched-bench"
export MODEL_PATH="/models"
./gpu_stress_test.sh --stress-test --max-batch 256 --step 8 --duration 60 llama-7b.gguf
```

## Migration from Legacy Mode

If you were using the original stress test parameters, you can migrate to the more flexible direct mode:

**Old (Legacy):**
```bash
./gpu_stress_test.sh -c 4096 -m 256 -s 8 -d 60 model.gguf
```

**New (Direct):**
```bash
./gpu_stress_test.sh -c 4096 -npl 8,16,24,32,40,48,56,64,72,80,88,96,104,112,120,128,136,144,152,160,168,176,184,192,200,208,216,224,232,240,248,256 model.gguf
```

Or continue using legacy mode:
```bash
./gpu_stress_test.sh --stress-test -c 4096 --max-batch 256 --step 8 --duration 60 model.gguf
```

## Prerequisites

- `batched-bench` executable from llama.cpp
- CUDA-compatible GPU (for GPU testing)
- Model files in GGUF format
- `bc` calculator (for duration calculations in legacy mode)
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

- Built as a wrapper for [llama.cpp](https://github.com/ggml-org/llama.cpp) `batched-bench` tool
- Designed for GPU stress testing and performance validation
- Maintains full compatibility with original `batched-bench` parameters