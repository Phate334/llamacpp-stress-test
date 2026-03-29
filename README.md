# llama.cpp Stress Test Helper

This repository provides a bash wrapper for llama.cpp's `llama-batched-bench`, used via Docker containers only: mount `bench-helper.sh` into the official llama.cpp image and run it to collect results.

![Results viewer screenshot](./demo.png)

### Docker Compose (recommended)

Edit `compose.yaml` if needed, then run the benchmark service (service name: `test`):

```bash
docker compose up test
```

Results appear in `results/YYYYMMDD_HHMMSS/`.

To serve historical results via a simple HTTP server:

```bash
docker compose up server
# Open http://localhost:8000/results.html
```

Key points from the provided `compose.yaml`:

- Image: `ghcr.io/ggml-org/llama.cpp:full-cuda-b8576`
- Uses Hugging Face repo download (`-hf lmstudio-community/gemma-3-1B-it-qat-GGUF:Q4_0`) instead of a pre-mounted model file
- Caches downloads under a writable host directory mapped to `/root/.cache` so both Hugging Face model files and llama.cpp preset/cache files persist across runs
- Pins `--fit off` in the example for reproducible benchmark parameters on newer llama.cpp builds
- Limits parallel prompt list to `-npl 1,2,3` in the example
- Keeps `-b` and `-ub` at llama.cpp defaults in the example so the baseline stays simple before tuning

### One-line Docker run (equivalent to compose.yaml `test` service)

```bash
docker run --rm --gpus all \
  -v "$(pwd)/model-cache:/root/.cache" \
  -v "$(pwd)/results:/app/results" \
  -v "$(pwd)/bench-helper.sh:/app/bench-helper.sh" \
  --entrypoint /app/bench-helper.sh \
  ghcr.io/ggml-org/llama.cpp:full-cuda-b8576 \
  -hf lmstudio-community/gemma-3-1B-it-qat-GGUF:Q4_0 \
  -ngl 99 -c 4096 -fa on --fit off \
  -npp 256 -ntg 128 -npl 1,2,3
```

If you prefer mounting a local model instead of `-hf`, replace the `-hf ...` argument with something like:

```bash
-m /app/models/your-model.gguf
```

and mount your host `models` directory: `-v "$(pwd)/models:/app/models"`.

When using `-hf`, llama.cpp stores the GGUF payload under `/root/.cache/huggingface/...` and may also use `/root/.cache/llama.cpp/...` for presets. Mounting the host `model-cache` directory to `/root/.cache` preserves both.

### Script behavior and options

- Forces `--output-format jsonl` for consistent parsing. Any user-provided `--output-format` is ignored with a warning.
- `-o, --output-dir DIR`: save into a custom directory; otherwise creates `results/YYYYMMDD_HHMMSS/`.
- `-h, --help`: proxies to `/app/llama-batched-bench -h` inside the container.
- Captures environment info (GPU via nvidia-smi, CPU, RAM) before running the bench.
- The example uses `-fa on` because newer llama.cpp builds expose `--flash-attn` as an explicit `on|off|auto` option.
- The example also sets `--fit off` so benchmark runs keep the requested parameters instead of silently auto-adjusting them.

## Why tune `-b` and `-ub`

In current llama.cpp builds, these two flags control different layers of batching:

- `-b, --batch-size`: logical maximum batch size. This is the larger scheduling limit.
- `-ub, --ubatch-size`: physical maximum batch size. This is the chunk size actually processed by the backend at a time.

Why change them:

- Larger `-b` can improve prompt processing throughput (`PP`) because more prompt tokens can be scheduled together.
- Larger `-ub` can improve GPU utilization, but it also increases compute buffer pressure and may reduce generation throughput (`TG`) or leave fewer tensors/layers fitting comfortably in VRAM.
- The best pair is workload-specific. A setting that is best for long prompt ingestion is often not the best for token generation.

Why this repo keeps them out of the default example:

- The shipped compose example is meant to be a reproducible baseline.
- `-b` and `-ub` are hardware-sensitive tuning knobs, so hard-coding a single "best" value in the README would be misleading.
- During tuning, `--fit off` is recommended so llama.cpp does not silently change other parameters while you are trying to compare only batch behavior.

As a practical rule:

- Start with llama.cpp defaults.
- Increase `-ub` first to see whether the GPU gets better prompt throughput without hurting generation too much.
- Then increase `-b` to see whether prompt-heavy workloads improve further.
- Validate the final top 1-2 candidates on your real server workload, not only in `llama-bench`.

## Batch tuning helper

This repository includes [`tune-batch.sh`](/home/phate/llamacpp-stress-test/tune-batch.sh), a helper that runs a `-b x -ub` sweep with `docker compose run --rm` and summarizes the best combinations.

Default behavior:

- Uses the `test` service from `compose.yaml`
- Runs `/app/llama-bench` directly
- Tests several `-b` and `-ub` values in one pass
- Writes `raw.csv`, `summary.tsv`, and `recommendations.txt`
- Reports three picks: best balanced, best prompt throughput, and best generation throughput

Basic usage:

```bash
./tune-batch.sh
```

Custom sweep:

```bash
./tune-batch.sh -b 1024,2048,4096 -u 256,512,1024
```

Override the benchmark arguments after `--`:

```bash
./tune-batch.sh -b 1024,2048,4096 -u 256,512,1024 -- \
  -hf lmstudio-community/gemma-3-1B-it-qat-GGUF:Q4_0 \
  -ngl 99 -fa 1 -ctk f16 -ctv f16 -p 512 -n 128
```

The helper is intended for causal generation models. If you later adapt it to embeddings or other non-causal models, do not assume that `-b > -ub` is always valid.

## Output Files

Each benchmark execution creates a new directory under `results/` in the format `results/YYYYMMDD_HHMMSS/`.

The wrapper script writes:

1. **Benchmark Results** (`output.jsonl`): Contains line-by-line test results.
2. **Environment Metadata** (`environment.json`): Includes system information and test parameters.

The results viewer is the repository file `results/results.html`. It is not generated per run. Start the HTTP server with `docker compose up server`, then open `http://localhost:8000/results.html` to browse all timestamped runs.

## Requirements

- Docker
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)

## Quick setup

```bash
# Clone the repository
git clone https://github.com/Phate334/llamacpp-stress-test.git
cd llamacpp-stress-test

# Make the scripts executable (if needed for local runs)
chmod +x bench-helper.sh
chmod +x tune-batch.sh
```

## Acknowledgments

- Built as a wrapper for [llama.cpp](https://github.com/ggml-org/llama.cpp) `batched-bench` tool.
- Uses [charts.css](https://github.com/ChartsCSS/charts.css) to display charts.
