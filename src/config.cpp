#include "config.h"
#include <iostream>
#include <fstream>
#include <sstream>
#include <cstring>

bool StressTestConfig::load_from_file(const std::string& config_file) {
    // Simple key-value parser for configuration files
    std::ifstream file(config_file);
    if (!file.is_open()) {
        return false;
    }
    
    std::string line;
    while (std::getline(file, line)) {
        // Skip comments and empty lines
        if (line.empty() || line[0] == '#') continue;
        
        size_t pos = line.find('=');
        if (pos == std::string::npos) continue;
        
        std::string key = line.substr(0, pos);
        std::string value = line.substr(pos + 1);
        
        // Trim whitespace
        key.erase(0, key.find_first_not_of(" \t"));
        key.erase(key.find_last_not_of(" \t") + 1);
        value.erase(0, value.find_first_not_of(" \t"));
        value.erase(value.find_last_not_of(" \t") + 1);
        
        // Parse configuration values
        if (key == "test_duration") {
            test_duration = std::chrono::seconds(std::stoi(value));
        } else if (key == "max_concurrent_batches") {
            max_concurrent_batches = std::stoi(value);
        } else if (key == "max_memory_mb") {
            max_memory_mb = std::stoi(value);
        } else if (key == "output_format") {
            output_format = value;
        } else if (key == "output_file") {
            output_file = value;
        } else if (key == "model_path") {
            model_path = value;
        } else if (key == "context_size") {
            context_size = std::stoi(value);
        } else if (key == "gpu_layers") {
            gpu_layers = std::stoi(value);
        } else if (key == "threads") {
            threads = std::stoi(value);
        } else if (key == "verbose") {
            verbose = (value == "true" || value == "1");
        }
    }
    
    return true;
}

bool StressTestConfig::save_to_file(const std::string& config_file) const {
    std::ofstream file(config_file);
    if (!file.is_open()) {
        return false;
    }
    
    file << "# LlamaCPP Stress Test Configuration\n";
    file << "test_duration=" << test_duration.count() << "\n";
    file << "max_concurrent_batches=" << max_concurrent_batches << "\n";
    file << "max_memory_mb=" << max_memory_mb << "\n";
    file << "output_format=" << output_format << "\n";
    file << "output_file=" << output_file << "\n";
    file << "model_path=" << model_path << "\n";
    file << "context_size=" << context_size << "\n";
    file << "gpu_layers=" << gpu_layers << "\n";
    file << "threads=" << threads << "\n";
    file << "verbose=" << (verbose ? "true" : "false") << "\n";
    
    return true;
}

bool StressTestConfig::parse_args(int argc, char** argv) {
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        
        if (arg == "-h" || arg == "--help") {
            print_usage(argv[0]);
            return false;
        } else if (arg == "-c" || arg == "--config") {
            if (i + 1 < argc) {
                return load_from_file(argv[++i]);
            }
        } else if (arg == "-d" || arg == "--duration") {
            if (i + 1 < argc) {
                test_duration = std::chrono::seconds(std::stoi(argv[++i]));
            }
        } else if (arg == "-b" || arg == "--max-batches") {
            if (i + 1 < argc) {
                max_concurrent_batches = std::stoi(argv[++i]);
            }
        } else if (arg == "-m" || arg == "--model") {
            if (i + 1 < argc) {
                model_path = argv[++i];
            }
        } else if (arg == "-o" || arg == "--output") {
            if (i + 1 < argc) {
                output_file = argv[++i];
            }
        } else if (arg == "-f" || arg == "--format") {
            if (i + 1 < argc) {
                output_format = argv[++i];
            }
        } else if (arg == "-v" || arg == "--verbose") {
            verbose = true;
        } else if (arg == "--context-size") {
            if (i + 1 < argc) {
                context_size = std::stoi(argv[++i]);
            }
        } else if (arg == "--gpu-layers") {
            if (i + 1 < argc) {
                gpu_layers = std::stoi(argv[++i]);
            }
        } else if (arg == "--threads") {
            if (i + 1 < argc) {
                threads = std::stoi(argv[++i]);
            }
        }
    }
    
    return true;
}

void StressTestConfig::print_usage(const char* program_name) {
    std::cout << "LlamaCPP Stress Test Tool\n\n";
    std::cout << "Usage: " << program_name << " [options]\n\n";
    std::cout << "Options:\n";
    std::cout << "  -h, --help                   Show this help message\n";
    std::cout << "  -c, --config FILE            Load configuration from file\n";
    std::cout << "  -d, --duration SECONDS       Test duration in seconds (default: 60)\n";
    std::cout << "  -b, --max-batches NUM        Maximum concurrent batches (default: 32)\n";
    std::cout << "  -m, --model PATH             Path to model file (for llama.cpp integration)\n";
    std::cout << "  -o, --output FILE            Output file (default: stress_test_results.json)\n";
    std::cout << "  -f, --format FORMAT          Output format: json, csv, markdown (default: json)\n";
    std::cout << "  -v, --verbose                Enable verbose output\n";
    std::cout << "      --context-size SIZE      Context size (default: 2048)\n";
    std::cout << "      --gpu-layers NUM         Number of GPU layers (default: 0)\n";
    std::cout << "      --threads NUM            Number of threads (default: 4)\n\n";
    std::cout << "Examples:\n";
    std::cout << "  " << program_name << " --duration 300 --max-batches 64 --verbose\n";
    std::cout << "  " << program_name << " --model model.gguf --context-size 4096 --gpu-layers 32\n";
    std::cout << "  " << program_name << " --config stress_test.conf --output results.json\n";
}

bool StressTestConfig::validate() const {
    if (test_duration.count() <= 0) {
        std::cerr << "Error: Test duration must be positive\n";
        return false;
    }
    
    if (max_concurrent_batches <= 0) {
        std::cerr << "Error: Max concurrent batches must be positive\n";
        return false;
    }
    
    if (max_memory_mb <= 0) {
        std::cerr << "Error: Max memory must be positive\n";
        return false;
    }
    
    if (output_format != "json" && output_format != "csv" && output_format != "markdown") {
        std::cerr << "Error: Output format must be json, csv, or markdown\n";
        return false;
    }
    
    if (context_size <= 0) {
        std::cerr << "Error: Context size must be positive\n";
        return false;
    }
    
    if (threads <= 0) {
        std::cerr << "Error: Number of threads must be positive\n";
        return false;
    }
    
    return true;
}