#pragma once

#include <chrono>
#include <string>
#include <atomic>
#include <thread>
#include <functional>

/**
 * Resource monitor for tracking system resources during stress tests
 */
struct ResourceSnapshot {
    std::chrono::steady_clock::time_point timestamp;
    size_t memory_used_mb{0};
    size_t memory_available_mb{0};
    double cpu_usage_percent{0.0};
    size_t active_threads{0};
    size_t active_batches{0};
    std::string status{"running"};
};

class ResourceMonitor {
public:
    ResourceMonitor();
    ~ResourceMonitor();
    
    // Start monitoring with specified interval
    void start_monitoring(std::chrono::milliseconds interval);
    
    // Stop monitoring
    void stop_monitoring();
    
    // Get current resource snapshot
    ResourceSnapshot get_current_snapshot() const;
    
    // Get all collected snapshots
    const std::vector<ResourceSnapshot>& get_snapshots() const;
    
    // Set callback for resource limit violations
    void set_limit_callback(std::function<void(const ResourceSnapshot&)> callback);
    
    // Set resource limits
    void set_memory_limit_mb(size_t limit);
    void set_cpu_limit_percent(double limit);
    
    // Update active batch count (called by stress test engine)
    void set_active_batches(size_t count);
    
    // Clear collected data
    void clear_snapshots();
    
private:
    std::vector<ResourceSnapshot> snapshots_;
    std::atomic<bool> monitoring_{false};
    std::thread monitor_thread_;
    std::atomic<size_t> active_batches_{0};
    
    // Resource limits
    std::atomic<size_t> memory_limit_mb_{0};
    std::atomic<double> cpu_limit_percent_{100.0};
    
    // Callback for limit violations
    std::function<void(const ResourceSnapshot&)> limit_callback_;
    
    // Platform-specific resource collection
    size_t get_memory_usage_mb() const;
    size_t get_available_memory_mb() const;
    double get_cpu_usage_percent() const;
    size_t get_active_thread_count() const;
    
    // Monitoring loop
    void monitoring_loop(std::chrono::milliseconds interval);
    
    // Check if limits are exceeded
    bool check_limits(const ResourceSnapshot& snapshot) const;
};