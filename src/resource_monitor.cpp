#include "resource_monitor.h"
#include <fstream>
#include <sstream>
#include <algorithm>

#ifdef _WIN32
#include <windows.h>
#include <psapi.h>
#else
#include <unistd.h>
#include <sys/resource.h>
#include <sys/sysinfo.h>
#endif

ResourceMonitor::ResourceMonitor() = default;

ResourceMonitor::~ResourceMonitor() {
    stop_monitoring();
}

void ResourceMonitor::start_monitoring(std::chrono::milliseconds interval) {
    if (monitoring_.load()) {
        return; // Already monitoring
    }
    
    monitoring_.store(true);
    monitor_thread_ = std::thread(&ResourceMonitor::monitoring_loop, this, interval);
}

void ResourceMonitor::stop_monitoring() {
    if (monitoring_.load()) {
        monitoring_.store(false);
        if (monitor_thread_.joinable()) {
            monitor_thread_.join();
        }
    }
}

ResourceSnapshot ResourceMonitor::get_current_snapshot() const {
    ResourceSnapshot snapshot;
    snapshot.timestamp = std::chrono::steady_clock::now();
    snapshot.memory_used_mb = get_memory_usage_mb();
    snapshot.memory_available_mb = get_available_memory_mb();
    snapshot.cpu_usage_percent = get_cpu_usage_percent();
    snapshot.active_threads = get_active_thread_count();
    snapshot.active_batches = active_batches_.load();
    return snapshot;
}

const std::vector<ResourceSnapshot>& ResourceMonitor::get_snapshots() const {
    return snapshots_;
}

void ResourceMonitor::set_limit_callback(std::function<void(const ResourceSnapshot&)> callback) {
    limit_callback_ = std::move(callback);
}

void ResourceMonitor::set_memory_limit_mb(size_t limit) {
    memory_limit_mb_.store(limit);
}

void ResourceMonitor::set_cpu_limit_percent(double limit) {
    cpu_limit_percent_.store(limit);
}

void ResourceMonitor::set_active_batches(size_t count) {
    active_batches_.store(count);
}

void ResourceMonitor::clear_snapshots() {
    snapshots_.clear();
}

size_t ResourceMonitor::get_memory_usage_mb() const {
#ifdef _WIN32
    PROCESS_MEMORY_COUNTERS pmc;
    if (GetProcessMemoryInfo(GetCurrentProcess(), &pmc, sizeof(pmc))) {
        return pmc.WorkingSetSize / (1024 * 1024);
    }
    return 0;
#else
    // Read from /proc/self/status
    std::ifstream status_file("/proc/self/status");
    std::string line;
    while (std::getline(status_file, line)) {
        if (line.find("VmRSS:") == 0) {
            std::istringstream iss(line);
            std::string key, value, unit;
            iss >> key >> value >> unit;
            return std::stoul(value) / 1024; // Convert KB to MB
        }
    }
    return 0;
#endif
}

size_t ResourceMonitor::get_available_memory_mb() const {
#ifdef _WIN32
    MEMORYSTATUSEX memInfo;
    memInfo.dwLength = sizeof(MEMORYSTATUSEX);
    if (GlobalMemoryStatusEx(&memInfo)) {
        return memInfo.ullAvailPhys / (1024 * 1024);
    }
    return 0;
#else
    struct sysinfo info;
    if (sysinfo(&info) == 0) {
        return (info.freeram * info.mem_unit) / (1024 * 1024);
    }
    return 0;
#endif
}

double ResourceMonitor::get_cpu_usage_percent() const {
    // Simplified CPU usage calculation
    // In a real implementation, you'd want to track CPU time over intervals
    static auto last_time = std::chrono::steady_clock::now();
    static clock_t last_cpu = clock();
    
    auto current_time = std::chrono::steady_clock::now();
    clock_t current_cpu = clock();
    
    auto time_diff = std::chrono::duration_cast<std::chrono::milliseconds>(
        current_time - last_time).count();
    auto cpu_diff = current_cpu - last_cpu;
    
    last_time = current_time;
    last_cpu = current_cpu;
    
    if (time_diff > 0) {
        double cpu_usage = (static_cast<double>(cpu_diff) / CLOCKS_PER_SEC) * 1000.0 / time_diff * 100.0;
        return std::min(cpu_usage, 100.0);
    }
    
    return 0.0;
}

size_t ResourceMonitor::get_active_thread_count() const {
#ifdef _WIN32
    // Windows implementation would require additional APIs
    return 1; // Simplified
#else
    // Count threads in /proc/self/task
    std::ifstream stat_file("/proc/self/stat");
    if (stat_file.is_open()) {
        std::string line;
        std::getline(stat_file, line);
        std::istringstream iss(line);
        std::string token;
        for (int i = 0; i < 19; ++i) {
            iss >> token;
        }
        iss >> token; // 20th field is num_threads
        return std::stoul(token);
    }
    return 1;
#endif
}

void ResourceMonitor::monitoring_loop(std::chrono::milliseconds interval) {
    while (monitoring_.load()) {
        try {
            ResourceSnapshot snapshot = get_current_snapshot();
            
            // Check limits and call callback if exceeded
            if (check_limits(snapshot) && limit_callback_) {
                limit_callback_(snapshot);
            }
            
            snapshots_.push_back(snapshot);
            
        } catch (const std::exception& e) {
            // Log error but continue monitoring
            // std::cerr << "Monitoring error: " << e.what() << std::endl;
        }
        
        std::this_thread::sleep_for(interval);
    }
}

bool ResourceMonitor::check_limits(const ResourceSnapshot& snapshot) const {
    size_t mem_limit = memory_limit_mb_.load();
    double cpu_limit = cpu_limit_percent_.load();
    
    if (mem_limit > 0 && snapshot.memory_used_mb > mem_limit) {
        return true;
    }
    
    if (cpu_limit < 100.0 && snapshot.cpu_usage_percent > cpu_limit) {
        return true;
    }
    
    return false;
}