#!/bin/bash

# GPU Stress Test Script using batched-bench
# Compatible with llama.cpp tools/llama-batched-bench parameters
# Based on issue #3 requirements - support original batched-bench parameters

set -euo pipefail

# Default values
VERBOSE=false
OUTPUT_DIR="./results"

# Batched-bench compatible parameters with defaults
CONTEXT_LENGTH=2048
BATCH_SIZE=512
UBATCH_SIZE=512
GPU_LAYERS=0
MAIN_GPU=0
THREADS=""
THREADS_BATCH=""
SPLIT_MODE=""
TENSOR_SPLIT=""
FLASH_ATTN=false

# Stress test specific parameters (for compatibility mode)
MAX_BATCH_SIZE=512
STEP_SIZE=16
TEST_DURATION=30
COMPATIBILITY_MODE=false

# Arrays to store batched-bench specific parameters
declare -a NPP_VALUES=()
declare -a NTG_VALUES=()
declare -a NPL_VALUES=()
declare -a EXTRA_ARGS=()
PROMPT_SHARED=false
OUTPUT_FORMAT="md"

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTIONS] MODEL_NAME

GPU stress testing script compatible with llama.cpp batched-bench parameters.
Executes batched-bench and saves results in JSONL format for analysis.

ORIGINAL BATCHED-BENCH OPTIONS:
    -m, --model FILE        Model path (or use MODEL_NAME positional argument)
    -c, --ctx-size N        Context size (default: 2048)
    -b, --batch-size N      Logical batch size (default: 512)
    -ub, --ubatch-size N    Physical batch size (default: 512)
    -ngl, --n-gpu-layers N  Number of GPU layers to offload (default: 0)
    -mg, --main-gpu N       Main GPU device (default: 0)
    -t, --threads N         Number of threads for generation
    -tb, --threads-batch N  Number of threads for batch processing
    -sm, --split-mode MODE  Split mode: none, layer, row
    -ts, --tensor-split N,N Tensor split ratios
    -fa, --flash-attn       Enable flash attention
    -npp VALUES             Prompt tokens per sequence (comma-separated)
    -ntg VALUES             Tokens to generate per sequence (comma-separated)
    -npl VALUES             Number of parallel sequences (comma-separated)
    -pps                    Prompt is shared across sequences
    --output-format FORMAT  Output format: md or jsonl

WRAPPER-SPECIFIC OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -o, --output DIR        Output directory for results (default: ./results)
    --stress-test           Enable stress test mode (legacy compatibility)
    --max-batch SIZE        Maximum batch size for stress testing (default: 512)
    --step SIZE             Step size for batch increments (default: 16)
    --duration SECONDS      Test duration per batch size (default: 30)

ENVIRONMENT VARIABLES:
    BATCHED_BENCH_PATH      Path to batched-bench executable (required)
    MODEL_PATH              Path to model files directory (required)

EXAMPLES:
    # Basic batched-bench usage with JSONL output
    BATCHED_BENCH_PATH=/path/to/batched-bench MODEL_PATH=/models \\
        $0 -c 2048 -b 512 -ub 256 -ngl 99 model.gguf

    # Stress test mode (legacy)
    BATCHED_BENCH_PATH=/path/to/batched-bench MODEL_PATH=/models \\
        $0 --stress-test --max-batch 256 --step 8 --duration 60 model.gguf
    
    # With specific test configurations
    BATCHED_BENCH_PATH=/path/to/batched-bench MODEL_PATH=/models \\
        $0 -npp 128,256,512 -ntg 128,256 -npl 1,2,4,8 model.gguf

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
            # Batched-bench compatible parameters
            -m|--model)
                # Handle model parameter (but prefer positional argument)
                if [[ -z "${MODEL_NAME:-}" ]]; then
                    MODEL_NAME="$2"
                fi
                shift 2
                ;;
            -c|--ctx-size)
                CONTEXT_LENGTH="$2"
                shift 2
                ;;
            -b|--batch-size)
                BATCH_SIZE="$2"
                shift 2
                ;;
            -ub|--ubatch-size)
                UBATCH_SIZE="$2"
                shift 2
                ;;
            -ngl|--n-gpu-layers)
                GPU_LAYERS="$2"
                shift 2
                ;;
            -mg|--main-gpu)
                MAIN_GPU="$2"
                shift 2
                ;;
            -t|--threads)
                THREADS="$2"
                shift 2
                ;;
            -tb|--threads-batch)
                THREADS_BATCH="$2"
                shift 2
                ;;
            -sm|--split-mode)
                SPLIT_MODE="$2"
                shift 2
                ;;
            -ts|--tensor-split)
                TENSOR_SPLIT="$2"
                shift 2
                ;;
            -fa|--flash-attn)
                FLASH_ATTN=true
                shift
                ;;
            -npp)
                IFS=',' read -ra NPP_VALUES <<< "$2"
                shift 2
                ;;
            -ntg)
                IFS=',' read -ra NTG_VALUES <<< "$2"
                shift 2
                ;;
            -npl)
                IFS=',' read -ra NPL_VALUES <<< "$2"
                shift 2
                ;;
            -pps)
                PROMPT_SHARED=true
                shift
                ;;
            --output-format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            # Stress test mode (legacy compatibility)
            --stress-test)
                COMPATIBILITY_MODE=true
                shift
                ;;
            --max-batch)
                MAX_BATCH_SIZE="$2"
                shift 2
                ;;
            --step)
                STEP_SIZE="$2"
                shift 2
                ;;
            --duration|-d)
                TEST_DURATION="$2"
                shift 2
                ;;
            # Legacy compatibility aliases
            --context)
                CONTEXT_LENGTH="$2"
                shift 2
                ;;
            -s)
                STEP_SIZE="$2"
                shift 2
                ;;
            # Pass through other arguments
            -*)
                EXTRA_ARGS+=("$1")
                if [[ $# -gt 1 && ! "$2" =~ ^- ]]; then
                    EXTRA_ARGS+=("$2")
                    shift 2
                else
                    shift
                fi
                ;;
            *)
                if [[ -z "${MODEL_NAME:-}" ]]; then
                    MODEL_NAME="$1"
                fi
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
            "batch_size": $BATCH_SIZE,
            "ubatch_size": $UBATCH_SIZE,
            "gpu_layers": $GPU_LAYERS,
            "main_gpu": $MAIN_GPU,
            "threads": "${THREADS:-auto}",
            "threads_batch": "${THREADS_BATCH:-auto}",
            "split_mode": "${SPLIT_MODE:-default}",
            "tensor_split": "${TENSOR_SPLIT:-default}",
            "flash_attn": $FLASH_ATTN,
            "prompt_shared": $PROMPT_SHARED,
            "output_format": "$OUTPUT_FORMAT",
            "compatibility_mode": $COMPATIBILITY_MODE,
            "npp_values": [$(IFS=','; echo "${NPP_VALUES[*]}" | sed 's/,/", "/g' | sed 's/^/"/;s/$/"/')],
            "ntg_values": [$(IFS=','; echo "${NTG_VALUES[*]}" | sed 's/,/", "/g' | sed 's/^/"/;s/$/"/')],
            "npl_values": [$(IFS=','; echo "${NPL_VALUES[*]}" | sed 's/,/", "/g' | sed 's/^/"/;s/$/"/')]
        },
        "legacy_stress_test_parameters": {
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
            "cuda_visible_devices": "${CUDA_VISIBLE_DEVICES:-all}",
            "batched_bench_command": "$(build_batched_bench_command)"
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

# Build batched-bench command with all parameters
build_batched_bench_command() {
    local model_file="$MODEL_PATH/$MODEL_NAME"
    local cmd=("$BATCHED_BENCH_PATH")
    
    # Core parameters
    cmd+=("-m" "$model_file")
    cmd+=("-c" "$CONTEXT_LENGTH")
    cmd+=("-b" "$BATCH_SIZE")
    cmd+=("-ub" "$UBATCH_SIZE")
    
    # GPU parameters
    if [[ $GPU_LAYERS -gt 0 ]]; then
        cmd+=("-ngl" "$GPU_LAYERS")
    fi
    if [[ $MAIN_GPU -gt 0 ]]; then
        cmd+=("-mg" "$MAIN_GPU")
    fi
    
    # Threading parameters
    if [[ -n "$THREADS" ]]; then
        cmd+=("-t" "$THREADS")
    fi
    if [[ -n "$THREADS_BATCH" ]]; then
        cmd+=("-tb" "$THREADS_BATCH")
    fi
    
    # Model parameters
    if [[ -n "$SPLIT_MODE" ]]; then
        cmd+=("-sm" "$SPLIT_MODE")
    fi
    if [[ -n "$TENSOR_SPLIT" ]]; then
        cmd+=("-ts" "$TENSOR_SPLIT")
    fi
    if [[ "$FLASH_ATTN" == "true" ]]; then
        cmd+=("-fa")
    fi
    
    # Benchmark parameters
    if [[ ${#NPP_VALUES[@]} -gt 0 ]]; then
        local npp_str=$(IFS=','; echo "${NPP_VALUES[*]}")
        cmd+=("-npp" "$npp_str")
    fi
    if [[ ${#NTG_VALUES[@]} -gt 0 ]]; then
        local ntg_str=$(IFS=','; echo "${NTG_VALUES[*]}")
        cmd+=("-ntg" "$ntg_str")
    fi
    if [[ ${#NPL_VALUES[@]} -gt 0 ]]; then
        local npl_str=$(IFS=','; echo "${NPL_VALUES[*]}")
        cmd+=("-npl" "$npl_str")
    fi
    if [[ "$PROMPT_SHARED" == "true" ]]; then
        cmd+=("-pps")
    fi
    
    # Always force JSONL output for parsing
    cmd+=("--output-format" "jsonl")
    
    # Add any extra arguments
    if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
        cmd+=("${EXTRA_ARGS[@]}")
    fi
    
    echo "${cmd[@]}"
}

# Run batched-bench with direct parameter pass-through
run_batched_bench() {
    local cmd_array=($(build_batched_bench_command))
    
    log "Running batched-bench with parameters: ${cmd_array[*]}"
    
    # Run batched-bench and capture output
    local start_time=$(date +%s.%N)
    local output
    local exit_code=0
    
    if output=$("${cmd_array[@]}" 2>&1); then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l)
        
        log "Batched-bench completed successfully in ${duration}s"
        
        # Parse and output JSONL (batched-bench already outputs JSONL)
        echo "$output"
        return 0
    else
        exit_code=$?
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l)
        
        log "Batched-bench failed with exit code $exit_code after ${duration}s"
        
        # Output error in JSONL format
        cat << EOF
{"status": "error", "exit_code": $exit_code, "duration": $duration, "error": "$(echo "$output" | head -5 | tr '\n' ' ' | sed 's/"/\\"/g')", "timestamp": "$(date -Iseconds)"}
EOF
        return $exit_code
    fi
}

# Legacy stress test mode for backward compatibility  
run_stress_test() {
    log "Running in legacy stress test mode"
    
    # Set default test parameters if not specified
    if [[ ${#NPP_VALUES[@]} -eq 0 ]]; then
        NPP_VALUES=(128)
    fi
    if [[ ${#NTG_VALUES[@]} -eq 0 ]]; then
        NTG_VALUES=(128)  
    fi
    if [[ ${#NPL_VALUES[@]} -eq 0 ]]; then
        # Generate batch sizes from 1 to MAX_BATCH_SIZE with STEP_SIZE increments
        for ((batch_size = STEP_SIZE; batch_size <= MAX_BATCH_SIZE; batch_size += STEP_SIZE)); do
            NPL_VALUES+=($batch_size)
        done
    fi
    
    # Run batched-bench with generated parameters
    run_batched_bench
}

# Main function
main() {
    parse_args "$@"
    validate_setup
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local output_file="$OUTPUT_DIR/batched_bench_${timestamp}.jsonl"
    local meta_file="$OUTPUT_DIR/meta_${timestamp}.json"
    
    log "Starting batched-bench execution"
    log "Model: $MODEL_NAME"
    log "Context length: $CONTEXT_LENGTH"
    log "Batch size: $BATCH_SIZE"
    log "Output: $output_file"
    
    # Write meta information
    get_hardware_info > "$meta_file"
    log "Hardware info written to: $meta_file"
    
    # Run batched-bench (stress test mode or direct execution)
    echo "Starting batched-bench at $(date)" >&2
    if [[ "$COMPATIBILITY_MODE" == "true" ]]; then
        run_stress_test > "$output_file"
    else
        run_batched_bench > "$output_file"
    fi
    echo "Batched-bench completed at $(date)" >&2
    
    log "Results written to: $output_file"
    log "Execution completed successfully"
}

# Run main function
main "$@"