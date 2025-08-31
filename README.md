# llama.cpp Stress Test Helper

This repository provides a bash wrapper for llama.cpp's `llama-batched-bench`, used via Docker containers only: mount `bench-helper.sh` into the official llama.cpp image and run it to collect results. Inside the container, the bench executable path is `/app/llama-batched-bench`.

## Usage

Use this tool via Docker containers by mounting the script into the official llama.cpp image (bench path: `/app/llama-batched-bench`).

### Docker Compose (recommended)

Edit `compose.yaml` if needed, then run:

```bash
docker compose up app
```

Results will be saved under `results/YYYYMMDD_HHMMSS/`. To browse past runs with a simple HTTP server:

```bash
docker compose up server
# Open http://localhost:8000
```

### One-line Docker run (matches compose.yaml)

```bash
docker run --rm --gpus all \
  -v "$(pwd)/models:/app/models" \
  -v "$(pwd)/results:/app/results" \
  -v "$(pwd)/bench-helper.sh:/app/bench-helper.sh" \
  --entrypoint /app/bench-helper.sh \
  ghcr.io/ggml-org/llama.cpp:full-cuda-b6055 \
  -m /app/models/gemma-3-1b-it-UD-Q4_K_XL.gguf \
  -ngl 99 -c 4096 -fa -ctk q8_0 -ctv q8_0 \
  -npp 256 -ntg 128 -npl 1,2,3,4,5
```

### Script behavior and options

- Forces `--output-format jsonl` for consistent parsing. Any user-provided `--output-format` is ignored with a warning.
- `-o, --output-dir DIR`: save into a custom directory; otherwise creates `results/YYYYMMDD_HHMMSS/`.
- `-h, --help`: proxies to `/app/llama-batched-bench -h` inside the container.
- Captures environment info (GPU via nvidia-smi, CPU, RAM) before running the bench.

## Output Files

The script generates the following files in timestamp-based directories under `results/`:

Each execution creates a new directory with the format `results/YYYYMMDD_HHMMSS/` containing:

1. **Benchmark Results** (`output.jsonl`): Contains line-by-line test results.
2. **Environment Metadata** (`environment.json`): Includes system information and test parameters.
3. **Results Viewer** (`index.html`): HTML interface for viewing and analyzing results.

This allows you to keep multiple test runs organized by execution time.

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

- CUDA-compatible GPU and NVIDIA driver (for Docker `--gpus all`)
- The official llama.cpp Docker image (pinned in `compose.yaml`)
- `nvidia-smi` available in the container to collect GPU info

## Quick setup

```bash
# Clone the repository
git clone https://github.com/Phate334/llamacpp-stress-test.git
cd llamacpp-stress-test

# Make the script executable (if needed for local runs)
chmod +x bench-helper.sh
```

## Acknowledgments

- Built as a wrapper for [llama.cpp](https://github.com/ggml-org/llama.cpp) `batched-bench` tool.
- Designed for GPU stress testing and performance validation.
