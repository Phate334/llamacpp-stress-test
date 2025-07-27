#!/bin/bash

# GPU Stress Test Script using batched-bench
# Based on issue #1 requirements - test GPU capability using batched-bench tool

set -euo pipefail

# Default values
VERBOSE=false
OUTPUT_DIR="./results"
CONTEXT_LENGTH=2048
MAX_BATCH_SIZE=512
STEP_SIZE=16
TEST_DURATION=30

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS] MODEL_NAME

GPU stress testing script using llama.cpp batched-bench tool.

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -o, --output DIR        Output directory for results (default: ./results)
    -c, --context LENGTH    Context length (default: 2048)
    -m, --max-batch SIZE    Maximum batch size to test (default: 512)
    -s, --step SIZE         Step size for batch increments (default: 16)
    -d, --duration SECONDS  Test duration per batch size (default: 30)

ENVIRONMENT VARIABLES:
    BATCHED_BENCH_PATH      Path to batched-bench executable (required)
    MODEL_PATH              Path to model files directory (required)

EXAMPLES:
    # Basic usage
    BATCHED_BENCH_PATH=/path/to/batched-bench MODEL_PATH=/models $0 model.gguf
    
    # With custom parameters
    BATCHED_BENCH_PATH=/path/to/batched-bench MODEL_PATH=/models \\
        $0 -c 4096 -m 256 -s 8 -d 60 model.gguf

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -c|--context)
                CONTEXT_LENGTH="$2"
                shift 2
                ;;
            -m|--max-batch)
                MAX_BATCH_SIZE="$2"
                shift 2
                ;;
            -s|--step)
                STEP_SIZE="$2"
                shift 2
                ;;
            -d|--duration)
                TEST_DURATION="$2"
                shift 2
                ;;
            -*)
                echo "Error: Unknown option $1" >&2
                show_help
                exit 1
                ;;
            *)
                MODEL_NAME="$1"
                shift
                ;;
        esac
    done
}

# Validate environment and arguments
validate_setup() {
    if [[ -z "${BATCHED_BENCH_PATH:-}" ]]; then
        echo "Error: BATCHED_BENCH_PATH environment variable is required" >&2
        exit 1
    fi
    
    if [[ -z "${MODEL_PATH:-}" ]]; then
        echo "Error: MODEL_PATH environment variable is required" >&2
        exit 1
    fi
    
    if [[ -z "${MODEL_NAME:-}" ]]; then
        echo "Error: MODEL_NAME argument is required" >&2
        show_help
        exit 1
    fi
    
    if [[ ! -x "$BATCHED_BENCH_PATH" ]]; then
        echo "Error: batched-bench executable not found or not executable: $BATCHED_BENCH_PATH" >&2
        exit 1
    fi
    
    local model_file="$MODEL_PATH/$MODEL_NAME"
    if [[ ! -f "$model_file" ]]; then
        echo "Error: Model file not found: $model_file" >&2
        exit 1
    fi
    
    mkdir -p "$OUTPUT_DIR"
}

# Get system hardware information
get_hardware_info() {
    local timestamp=$(date -Iseconds)
    local hostname=$(hostname)
    
    cat << EOF
{
    "meta": {
        "timestamp": "$timestamp",
        "hostname": "$hostname",
        "test_parameters": {
            "model": "$MODEL_NAME",
            "context_length": $CONTEXT_LENGTH,
            "max_batch_size": $MAX_BATCH_SIZE,
            "step_size": $STEP_SIZE,
            "test_duration": $TEST_DURATION
        },
        "hardware": {
            "cpu": "$(grep 'model name' /proc/cpuinfo | head -1 | cut -d ':' -f2 | xargs)",
            "cpu_cores": $(nproc),
            "memory_gb": $(free -g | awk 'NR==2{printf "%.1f", $2}'),
            "gpu": "$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "N/A")",
            "gpu_memory_gb": "$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | awk '{printf "%.1f", $1/1024}' || echo "N/A")"
        },
        "environment": {
            "batched_bench_path": "$BATCHED_BENCH_PATH",
            "model_path": "$MODEL_PATH",
            "cuda_visible_devices": "${CUDA_VISIBLE_DEVICES:-all}"
        }
    }
}
EOF
}

# Log function
log() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
    fi
}

# Run single batch test
run_batch_test() {
    local batch_size=$1
    local model_file="$MODEL_PATH/$MODEL_NAME"
    
    log "Testing batch size: $batch_size"
    
    # Run batched-bench and capture output
    local start_time=$(date +%s.%N)
    local output
    local exit_code=0
    
    # Construct batched-bench command
    local cmd="$BATCHED_BENCH_PATH -m '$model_file' -c $CONTEXT_LENGTH -b $batch_size -ub $batch_size"
    
    if output=$(timeout ${TEST_DURATION}s bash -c "$cmd" 2>&1); then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l)
        
        # Parse output for performance metrics
        local tokens_per_second=$(echo "$output" | grep -oP 'tokens per second: \K[\d.]+' || echo "0")
        local prompt_eval_time=$(echo "$output" | grep -oP 'prompt eval time = \K[\d.]+' || echo "0")
        local eval_time=$(echo "$output" | grep -oP 'eval time = \K[\d.]+' || echo "0")
        
        # Output JSONL format
        cat << EOF
{"batch_size": $batch_size, "status": "success", "duration": $duration, "tokens_per_second": $tokens_per_second, "prompt_eval_time": $prompt_eval_time, "eval_time": $eval_time, "timestamp": "$(date -Iseconds)"}
EOF
    else
        exit_code=$?
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l)
        
        # Output error JSONL
        cat << EOF
{"batch_size": $batch_size, "status": "error", "exit_code": $exit_code, "duration": $duration, "error": "$(echo "$output" | head -3 | tr '\n' ' ' | sed 's/"/\\"/g')", "timestamp": "$(date -Iseconds)"}
EOF
        
        log "Batch size $batch_size failed with exit code $exit_code"
        return $exit_code
    fi
}

# Find critical batch size
find_critical_point() {
    local critical_point=0
    local consecutive_failures=0
    
    for ((batch_size = STEP_SIZE; batch_size <= MAX_BATCH_SIZE; batch_size += STEP_SIZE)); do
        if run_batch_test "$batch_size"; then
            critical_point=$batch_size
            consecutive_failures=0
        else
            ((consecutive_failures++))
            if [[ $consecutive_failures -ge 3 ]]; then
                log "Found critical point at batch size: $critical_point (3 consecutive failures)"
                break
            fi
        fi
    done
    
    echo "Critical batch size: $critical_point" >&2
    return 0
}

# Main function
main() {
    parse_args "$@"
    validate_setup
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local output_file="$OUTPUT_DIR/stress_test_${timestamp}.jsonl"
    local meta_file="$OUTPUT_DIR/meta_${timestamp}.json"
    
    log "Starting GPU stress test"
    log "Model: $MODEL_NAME"
    log "Context length: $CONTEXT_LENGTH"
    log "Max batch size: $MAX_BATCH_SIZE"
    log "Output: $output_file"
    
    # Write meta information
    get_hardware_info > "$meta_file"
    log "Hardware info written to: $meta_file"
    
    # Run stress test
    echo "Starting stress test at $(date)" >&2
    find_critical_point > "$output_file"
    echo "Stress test completed at $(date)" >&2
    
    log "Results written to: $output_file"
    log "Test completed successfully"
}

# Run main function
main "$@"