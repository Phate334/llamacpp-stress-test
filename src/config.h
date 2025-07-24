#pragma once

#include <string>
#include <vector>
#include <chrono>

/**
 * Configuration for stress testing scenarios
 */
struct StressTestConfig {
    // Test duration and timing
    std::chrono::seconds test_duration{60};
    std::chrono::milliseconds sampling_interval{100};
    
    // Batch configuration
    std::vector<int> batch_sizes{1, 2, 4, 8, 16, 32, 64, 128};
    std::vector<int> prompt_lengths{128, 256, 512, 1024};
    std::vector<int> generation_lengths{128, 256, 512};
    
    // Stress test parameters
    int max_concurrent_batches{32};
    int max_memory_mb{4096};
    bool test_memory_limits{true};
    bool test_error_recovery{true};
    bool test_sustained_load{true};
    
    // Output configuration
    std::string output_format{"json"}; // json, csv, markdown
    std::string output_file{"stress_test_results.json"};
    std::string log_file{"stress_test.log"};
    bool verbose{false};
    
    // Model configuration (if using llama.cpp)
    std::string model_path;
    int context_size{2048};
    int gpu_layers{0};
    int threads{4};
    
    // Load configuration from file
    bool load_from_file(const std::string& config_file);
    
    // Save configuration to file
    bool save_to_file(const std::string& config_file) const;
    
    // Parse command line arguments
    bool parse_args(int argc, char** argv);
    
    // Print usage information
    static void print_usage(const char* program_name);
    
    // Validate configuration
    bool validate() const;
};