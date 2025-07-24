cmake_minimum_required(VERSION 3.16)
project(llamacpp-stress-test VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages
find_package(Threads REQUIRED)

# Option to build with llama.cpp support
option(WITH_LLAMACPP "Build with llama.cpp integration" OFF)

# Include directories
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/src)

# Source files for the stress test tool
set(STRESS_TEST_SOURCES
    src/main.cpp
    src/stress_test.cpp
    src/config.cpp
    src/logger.cpp
    src/resource_monitor.cpp
)

# Main executable
add_executable(llamacpp-stress-test ${STRESS_TEST_SOURCES})

# Link libraries
target_link_libraries(llamacpp-stress-test PRIVATE Threads::Threads)

# If llama.cpp is available, enable integration
if(WITH_LLAMACPP)
    find_path(LLAMACPP_INCLUDE_DIR llama.h PATHS /usr/local/include /usr/include)
    find_library(LLAMACPP_LIBRARY llama PATHS /usr/local/lib /usr/lib)
    
    if(LLAMACPP_INCLUDE_DIR AND LLAMACPP_LIBRARY)
        target_include_directories(llamacpp-stress-test PRIVATE ${LLAMACPP_INCLUDE_DIR})
        target_link_libraries(llamacpp-stress-test PRIVATE ${LLAMACPP_LIBRARY})
        target_compile_definitions(llamacpp-stress-test PRIVATE WITH_LLAMACPP)
        message(STATUS "Building with llama.cpp support")
    else()
        message(WARNING "llama.cpp not found, building without llama.cpp integration")
    endif()
endif()

# Compiler flags
target_compile_options(llamacpp-stress-test PRIVATE
    $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall -Wextra -Wpedantic>
    $<$<CXX_COMPILER_ID:MSVC>:/W4>
)

# Install target
install(TARGETS llamacpp-stress-test RUNTIME DESTINATION bin)

# Create directories for build
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/logs)
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/reports)