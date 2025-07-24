#pragma once

#include <string>
#include <chrono>
#include <fstream>
#include <memory>

/**
 * Logger class for stress test output
 */
class Logger {
public:
    enum Level {
        DEBUG = 0,
        INFO = 1,
        WARNING = 2,
        ERROR = 3
    };
    
    explicit Logger(const std::string& log_file = "", Level min_level = INFO);
    ~Logger();
    
    void log(Level level, const std::string& message);
    void debug(const std::string& message);
    void info(const std::string& message);
    void warning(const std::string& message);
    void error(const std::string& message);
    
    void set_verbose(bool verbose);
    void set_min_level(Level level);
    
private:
    std::unique_ptr<std::ofstream> file_stream_;
    Level min_level_;
    bool verbose_;
    
    std::string level_to_string(Level level) const;
    std::string get_timestamp() const;
};