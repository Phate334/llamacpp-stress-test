#!/bin/bash

# Example stress test scenarios for different use cases

echo "LlamaCPP Stress Test Examples"
echo "============================"
echo

# Ensure we're in the build directory
cd build 2>/dev/null || echo "Run this from the project root directory"

echo "Example 1: Quick validation test"
echo "Running a 10-second test with minimal load..."
./llamacpp-stress-test --duration 10 --max-batches 4 --verbose --output example1_quick.json
echo

echo "Example 2: Memory stress test"
echo "Testing with higher batch counts to stress memory..."
./llamacpp-stress-test --duration 30 --max-batches 16 --output example2_memory.csv --format csv
echo

echo "Example 3: Sustained load test"
echo "Running longer test to check sustained performance..."
./llamacpp-stress-test --duration 120 --max-batches 8 --output example3_sustained.md --format markdown
echo

echo "Example 4: Configuration file usage"
echo "Using configuration file for reproducible tests..."
./llamacpp-stress-test --config ../example_config.conf --output example4_config.json
echo

echo "All examples completed. Check the output files for results."
echo "Files created:"
ls -la example*.json example*.csv example*.md 2>/dev/null || echo "No output files found"