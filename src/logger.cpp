#include "logger.h"
#include <iostream>
#include <iomanip>
#include <sstream>

Logger::Logger(const std::string& log_file, Level min_level) 
    : min_level_(min_level), verbose_(false) {
    if (!log_file.empty()) {
        file_stream_ = std::make_unique<std::ofstream>(log_file, std::ios::app);
    }
}

Logger::~Logger() = default;

void Logger::log(Level level, const std::string& message) {
    if (level < min_level_) {
        return;
    }
    
    std::string timestamp = get_timestamp();
    std::string level_str = level_to_string(level);
    std::string formatted_message = "[" + timestamp + "] [" + level_str + "] " + message;
    
    // Always write to console for errors and warnings, or if verbose
    if (level >= WARNING || verbose_) {
        std::cout << formatted_message << std::endl;
    }
    
    // Write to file if available
    if (file_stream_ && file_stream_->is_open()) {
        *file_stream_ << formatted_message << std::endl;
        file_stream_->flush();
    }
}

void Logger::debug(const std::string& message) {
    log(DEBUG, message);
}

void Logger::info(const std::string& message) {
    log(INFO, message);
}

void Logger::warning(const std::string& message) {
    log(WARNING, message);
}

void Logger::error(const std::string& message) {
    log(ERROR, message);
}

void Logger::set_verbose(bool verbose) {
    verbose_ = verbose;
}

void Logger::set_min_level(Level level) {
    min_level_ = level;
}

std::string Logger::level_to_string(Level level) const {
    switch (level) {
        case DEBUG: return "DEBUG";
        case INFO: return "INFO";
        case WARNING: return "WARN";
        case ERROR: return "ERROR";
        default: return "UNKNOWN";
    }
}

std::string Logger::get_timestamp() const {
    auto now = std::chrono::system_clock::now();
    auto time_t = std::chrono::system_clock::to_time_t(now);
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
        now.time_since_epoch()) % 1000;
    
    std::stringstream ss;
    ss << std::put_time(std::localtime(&time_t), "%Y-%m-%d %H:%M:%S");
    ss << '.' << std::setfill('0') << std::setw(3) << ms.count();
    
    return ss.str();
}