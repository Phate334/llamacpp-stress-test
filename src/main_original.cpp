#include "config.h"
#include "stress_test.h"
#include <iostream>
#include <cstdlib>

int main(int argc, char** argv) {
    std::cout << "LlamaCPP Stress Test Tool v1.0.0\n";
    std::cout << "==================================\n\n";
    
    // Parse configuration
    StressTestConfig config;
    if (!config.parse_args(argc, argv)) {
        return 1;
    }
    
    // Validate configuration
    if (!config.validate()) {
        std::cerr << "Configuration validation failed\n";
        return 1;
    }
    
    std::cout << "Configuration:\n";
    std::cout << "- Test duration: " << config.test_duration.count() << " seconds\n";
    std::cout << "- Max concurrent batches: " << config.max_concurrent_batches << "\n";
    std::cout << "- Max memory: " << config.max_memory_mb << " MB\n";
    std::cout << "- Output format: " << config.output_format << "\n";
    std::cout << "- Output file: " << config.output_file << "\n";
    if (!config.model_path.empty()) {
        std::cout << "- Model path: " << config.model_path << "\n";
        std::cout << "- Context size: " << config.context_size << "\n";
        std::cout << "- GPU layers: " << config.gpu_layers << "\n";
        std::cout << "- Threads: " << config.threads << "\n";
    }
    std::cout << "\n";
    
    try {
        // Initialize and run stress test
        StressTest stress_test(config);
        
        std::cout << "Starting stress test...\n\n";
        bool success = stress_test.run_all_tests();
        
        const auto& results = stress_test.get_results();
        
        // Print summary
        std::cout << "\n=======================================\n";
        std::cout << "Stress Test Summary\n";
        std::cout << "=======================================\n";
        std::cout << "Total test scenarios: " << results.size() << "\n";
        
        size_t total_requests = 0;
        size_t total_successful = 0;
        size_t total_failed = 0;
        size_t scenarios_with_memory_issues = 0;
        
        for (const auto& result : results) {
            total_requests += result.total_requests;
            total_successful += result.successful_requests;
            total_failed += result.failed_requests;
            if (result.memory_limit_exceeded) {
                scenarios_with_memory_issues++;
            }
        }
        
        std::cout << "Total requests: " << total_requests << "\n";
        std::cout << "Successful requests: " << total_successful << " (" << 
                     (total_requests > 0 ? (total_successful * 100.0 / total_requests) : 0) << "%)\n";
        std::cout << "Failed requests: " << total_failed << " (" << 
                     (total_requests > 0 ? (total_failed * 100.0 / total_requests) : 0) << "%)\n";
        std::cout << "Scenarios with memory issues: " << scenarios_with_memory_issues << "\n";
        
        // Find best and worst performing scenarios
        if (!results.empty()) {
            auto best_throughput = std::max_element(results.begin(), results.end(),
                [](const StressTestResult& a, const StressTestResult& b) {
                    return a.throughput_requests_per_sec < b.throughput_requests_per_sec;
                });
            
            auto worst_error_rate = std::max_element(results.begin(), results.end(),
                [](const StressTestResult& a, const StressTestResult& b) {
                    return a.get_error_rate() < b.get_error_rate();
                });
            
            std::cout << "\nBest performing scenario: " << best_throughput->test_name << 
                         " (" << best_throughput->throughput_requests_per_sec << " req/s)\n";
            std::cout << "Highest error rate: " << worst_error_rate->test_name << 
                         " (" << worst_error_rate->get_error_rate() << "%)\n";
        }
        
        std::cout << "\nResults exported to: " << config.output_file << "\n";
        
        if (success) {
            std::cout << "\nStress test completed successfully!\n";
            return 0;
        } else {
            std::cout << "\nStress test completed with issues. Check logs for details.\n";
            return 2;
        }
        
    } catch (const std::exception& e) {
        std::cerr << "Error running stress test: " << e.what() << "\n";
        return 1;
    }
}