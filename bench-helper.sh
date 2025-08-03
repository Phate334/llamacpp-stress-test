#!/bin/bash
set -euo pipefail

BASE_DIR="$(dirname "$(realpath "$0")")"

# Initialize arrays for storing arguments
BENCH_ARGS=()

# Default values
OUTPUT_DIR=$BASE_DIR/results
BENCH_EXECUTABLE="/app/llama-batched-bench"

# Function to show help by calling the bench executable
show_help() {
    if [ -x "$BENCH_EXECUTABLE" ]; then
        "$BENCH_EXECUTABLE" -h
    else
        echo "Error: BENCH_EXECUTABLE ($BENCH_EXECUTABLE) not found or not executable" >&2
        exit 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -o|--output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --output-format)
            # Skip this argument and its value since we force jsonl format
            echo "Warning: --output-format is forced to 'jsonl', ignoring user input"
            shift 2
            ;;
        *)
            # Store remaining arguments to pass to bench executable
            BENCH_ARGS+=("$1")
            shift
            ;;
    esac
done

# Function to collect environment information
collect_env_info() {
    local output_file="$1"
    local bench_args=("${@:2}")
    
    echo "Collecting environment information..."
    
    # Create JSON structure
    cat > "$output_file" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "bench_executable": "$BENCH_EXECUTABLE",
  "bench_arguments": [$(printf '"%s",' "${bench_args[@]}" | sed 's/,$//')],
EOF

    # Get GPU information using nvidia-smi
    if command -v nvidia-smi >/dev/null 2>&1; then
        echo "  \"gpu_info\": {" >> "$output_file"
        
        # Get GPU name and memory info in JSON format
        local gpu_json=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits | head -1)
        if [ $? -eq 0 ] && [ -n "$gpu_json" ]; then
            local gpu_name=$(echo "$gpu_json" | cut -d',' -f1 | sed 's/^[ \t]*//;s/[ \t]*$//')
            local gpu_memory=$(echo "$gpu_json" | cut -d',' -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')
            echo "    \"name\": \"$gpu_name\"," >> "$output_file"
            echo "    \"memory_total_mb\": $gpu_memory" >> "$output_file"
        else
            echo "    \"name\": \"Unknown\"," >> "$output_file"
            echo "    \"memory_total_mb\": 0" >> "$output_file"
        fi
        echo "  }," >> "$output_file"
    else
        echo "  \"gpu_info\": null," >> "$output_file"
    fi

    # Get CPU information
    echo "  \"cpu_info\": {" >> "$output_file"
    if [ -f /proc/cpuinfo ]; then
        local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')
        local cpu_cores=$(grep "processor" /proc/cpuinfo | wc -l)
        echo "    \"model\": \"$cpu_model\"," >> "$output_file"
        echo "    \"cores\": $cpu_cores" >> "$output_file"
    else
        echo "    \"model\": \"Unknown\"," >> "$output_file"
        echo "    \"cores\": 0" >> "$output_file"
    fi
    echo "  }," >> "$output_file"

    # Get RAM information
    echo "  \"memory_info\": {" >> "$output_file"
    if [ -f /proc/meminfo ]; then
        local total_memory_kb=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
        local total_memory_mb=$((total_memory_kb / 1024))
        local available_memory_kb=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}')
        local available_memory_mb=$((available_memory_kb / 1024))
        echo "    \"total_mb\": $total_memory_mb," >> "$output_file"
        echo "    \"available_mb\": $available_memory_mb" >> "$output_file"
    else
        echo "    \"total_mb\": 0," >> "$output_file"
        echo "    \"available_mb\": 0" >> "$output_file"
    fi
    echo "  }" >> "$output_file"

    # Close JSON
    echo "}" >> "$output_file"
    
    echo "Environment information saved to: $output_file"
}

# Main execution
main() {
    # Create output directory if it doesn't exist
    mkdir -p "$OUTPUT_DIR"
    
    # Define output file paths
    OUTPUT_FILE="$OUTPUT_DIR/output.jsonl"
    ENV_FILE="$OUTPUT_DIR/environment.json"
    
    echo "Running bench with arguments: ${BENCH_ARGS[*]}"
    echo "Output directory: $OUTPUT_DIR"
    echo "Output file: $OUTPUT_FILE"
    echo "Environment file: $ENV_FILE"

    # Collect environment information before running benchmark
    collect_env_info "$ENV_FILE" "${BENCH_ARGS[@]}" --output-format jsonl

    # Execute the bench executable with collected arguments
    if [ ${#BENCH_ARGS[@]} -gt 0 ]; then
        if [ -x "$BENCH_EXECUTABLE" ]; then
            # Force output format to jsonl and redirect to output file
            "$BENCH_EXECUTABLE" "${BENCH_ARGS[@]}" --output-format jsonl > "$OUTPUT_FILE"
            echo "Results saved to: $OUTPUT_FILE"
        else
            echo "Error: BENCH_EXECUTABLE ($BENCH_EXECUTABLE) not found or not executable" >&2
            exit 1
        fi
    else
        echo "No arguments provided. Use -h or --help to see available options."
        exit 1
    fi
}

# Run main function
main
