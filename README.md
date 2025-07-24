# LlamaCPP Stress Test Tool

A comprehensive stress testing tool for [llama.cpp](https://github.com/ggml-org/llama.cpp) that focuses on finding performance limits, testing error conditions, and validating system behavior under heavy load.

## Overview

This tool extends beyond simple benchmarking to provide stress testing capabilities that help identify:

- **System breaking points** under extreme load conditions
- **Memory and resource limits** with large batch sizes and long contexts
- **Error recovery behavior** when failures occur
- **Sustained performance** over extended time periods
- **Concurrent access patterns** with multiple parallel batches

Unlike the standard `batched-bench` tool from llama.cpp which focuses on performance benchmarking, this stress test tool is designed to:

1. **Push systems to their limits** to find failure modes
2. **Test error conditions and recovery** mechanisms
3. **Monitor resource usage** continuously during tests
4. **Validate sustained operation** over time
5. **Generate comprehensive reports** in multiple formats

## Features

### Stress Test Scenarios

1. **Sustained Load Test**: Run continuous batches for extended periods to test long-term stability
2. **Memory Limit Test**: Gradually increase batch sizes until memory limits are reached
3. **Batch Size Escalation**: Test increasing batch sizes to find performance degradation points
4. **Error Recovery Test**: Intentionally create problematic scenarios to test error handling
5. **Concurrent Access Test**: Test high concurrency scenarios with multiple parallel batches

### Monitoring and Reporting

- **Real-time resource monitoring**: CPU, memory, and thread usage
- **Comprehensive metrics**: Latency percentiles, throughput, error rates
- **Multiple output formats**: JSON, CSV, and Markdown reports
- **Configurable test parameters**: Duration, batch sizes, concurrency levels
- **Detailed logging**: With configurable verbosity levels

### Integration Options

- **Standalone mode**: Simulated inference for testing the tool itself
- **llama.cpp integration**: When built with `-DWITH_LLAMACPP=ON`, integrates with actual llama.cpp models
- **Flexible configuration**: Command-line arguments or configuration files

## Installation

### Prerequisites

- CMake 3.16 or higher
- C++17 compatible compiler (GCC 7+, Clang 5+, MSVC 2017+)
- Optional: llama.cpp library for actual model testing

### Building

```bash
# Clone the repository
git clone https://github.com/Phate334/llamacpp-stress-test.git
cd llamacpp-stress-test

# Build without llama.cpp (simulation mode)
mkdir build && cd build
cmake ..
make

# Build with llama.cpp integration (requires llama.cpp installed)
cmake -DWITH_LLAMACPP=ON ..
make
```

### Installation

```bash
# Install to system (optional)
sudo make install
```

## Usage

### Basic Usage

```bash
# Run default stress test (60 seconds, 32 max batches)
./llamacpp-stress-test

# Quick test with custom duration and batch limit
./llamacpp-stress-test --duration 30 --max-batches 16 --verbose

# Test with specific output format
./llamacpp-stress-test --duration 120 --output results.csv --format csv
```

### Advanced Usage

```bash
# Test with actual llama.cpp model
./llamacpp-stress-test --model /path/to/model.gguf --context-size 4096 --gpu-layers 32

# Use configuration file
./llamacpp-stress-test --config stress_test.conf

# Custom batch and prompt configurations
./llamacpp-stress-test --duration 300 --max-batches 64 --threads 8
```

### Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `-h, --help` | Show help message | - |
| `-c, --config FILE` | Load configuration from file | - |
| `-d, --duration SECONDS` | Test duration in seconds | 60 |
| `-b, --max-batches NUM` | Maximum concurrent batches | 32 |
| `-m, --model PATH` | Path to model file | - |
| `-o, --output FILE` | Output file | `stress_test_results.json` |
| `-f, --format FORMAT` | Output format: json, csv, markdown | json |
| `-v, --verbose` | Enable verbose output | false |
| `--context-size SIZE` | Context size | 2048 |
| `--gpu-layers NUM` | Number of GPU layers | 0 |
| `--threads NUM` | Number of threads | 4 |

### Configuration File Format

```ini
# LlamaCPP Stress Test Configuration
test_duration=300
max_concurrent_batches=64
max_memory_mb=8192
output_format=json
output_file=stress_results.json
model_path=/path/to/model.gguf
context_size=4096
gpu_layers=32
threads=8
verbose=true
```

## Output Formats

### JSON Output

```json
{
  "test_configuration": {
    "duration_seconds": 60,
    "max_concurrent_batches": 32,
    "max_memory_mb": 4096
  },
  "results": [
    {
      "test_name": "sustained_load_batch8",
      "batch_size": 8,
      "prompt_length": 256,
      "generation_length": 256,
      "concurrent_batches": 8,
      "total_requests": 45,
      "successful_requests": 43,
      "failed_requests": 2,
      "avg_latency_ms": 150.25,
      "p95_latency_ms": 245.50,
      "p99_latency_ms": 298.75,
      "throughput_requests_per_sec": 12.5,
      "peak_memory_mb": 1024,
      "error_rate_percent": 4.4
    }
  ]
}
```

### CSV Output

```csv
test_name,batch_size,prompt_length,generation_length,concurrent_batches,total_requests,successful_requests,failed_requests,avg_latency_ms,throughput_requests_per_sec,peak_memory_mb,error_rate_percent
sustained_load_batch8,8,256,256,8,45,43,2,150.25,12.5,1024,4.4
```

### Markdown Output

```markdown
# LlamaCPP Stress Test Results

## Test Configuration
- Duration: 60 seconds
- Max Concurrent Batches: 32
- Max Memory: 4096 MB

## Results Summary
| Test Name | Batch Size | Requests | Success Rate | Avg Latency (ms) | Throughput (req/s) | Peak Memory (MB) |
|-----------|------------|----------|--------------|------------------|-------------------|------------------|
| sustained_load_batch8 | 8 | 45 | 95.6% | 150.25 | 12.5 | 1024 |
```

## Interpreting Results

### Key Metrics

- **Success Rate**: Percentage of requests that completed successfully
- **Latency Percentiles**: P95 and P99 latencies indicate worst-case performance
- **Throughput**: Requests per second and estimated tokens per second
- **Resource Usage**: Peak memory and average CPU utilization
- **Error Rate**: Percentage of failed requests

### Stress Test Scenarios

1. **Sustained Load**: Tests long-term stability and performance consistency
2. **Memory Limit**: Identifies maximum batch sizes before memory exhaustion
3. **Escalation**: Shows performance degradation as load increases
4. **Error Recovery**: Validates system behavior under failure conditions
5. **Concurrent Access**: Tests scalability with multiple parallel requests

### Warning Signs

- **High error rates** (>10%) indicate system instability
- **Memory limit exceeded** warnings suggest insufficient resources
- **Increasing latency** with batch size indicates scalability limits
- **CPU usage near 100%** suggests compute bottlenecks

## Comparison with llama.cpp batched-bench

| Feature | batched-bench | llamacpp-stress-test |
|---------|---------------|---------------------|
| **Purpose** | Performance benchmarking | Stress testing and limits |
| **Duration** | Fixed test scenarios | Configurable sustained tests |
| **Error Testing** | Not focused on errors | Comprehensive error scenarios |
| **Resource Monitoring** | Basic | Continuous monitoring |
| **Failure Modes** | Not tested | Actively tested |
| **Output Formats** | Markdown, JSONL | JSON, CSV, Markdown |
| **Use Case** | Measure optimal performance | Find breaking points |

## Examples

### Find Memory Limits

```bash
# Test increasing batch sizes until memory limits
./llamacpp-stress-test --duration 60 --max-batches 128 --format markdown --output memory_test.md
```

### Sustained Load Testing

```bash
# Run 5-minute sustained load test
./llamacpp-stress-test --duration 300 --max-batches 32 --verbose
```

### Model-Specific Testing

```bash
# Test with actual model and GPU acceleration
./llamacpp-stress-test --model llama-7b.gguf --context-size 4096 --gpu-layers 32 --duration 180
```

### Custom Configuration

```bash
# Create and use custom configuration
cat > my_stress_test.conf << EOF
test_duration=600
max_concurrent_batches=64
max_memory_mb=16384
output_format=csv
verbose=true
EOF

./llamacpp-stress-test --config my_stress_test.conf
```

## Contributing

Contributions are welcome! Please feel free to submit pull requests, report issues, or suggest improvements.

## License

This project is licensed under the same license as the repository it belongs to.

## Acknowledgments

- Inspired by the [llama.cpp](https://github.com/ggml-org/llama.cpp) `batched-bench` tool
- Built for stress testing and reliability validation of language model inference systems