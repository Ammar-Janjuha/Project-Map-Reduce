#!/bin/bash

# run_all.sh - Run everything sequentially

echo "================================================"
echo "  COMPLETE MAPREDUCE BENCHMARK"
echo "================================================"
echo ""

# Run setup if needed
if [ ! -f serial_wordcount ] || [ ! -f parallel_wordcount ]; then
    echo "Setting up environment..."
    ./setup.sh
    echo ""
fi

# Run serial
echo "Step 1: Running serial version..."
./run_serial.sh
echo ""

# Run parallel
echo "Step 2: Running parallel version..."
./run_parallel.sh
echo ""

# Analyze performance
echo "Step 3: Analyzing performance..."
./analyze_performance.sh
echo ""

echo "================================================"
echo "  BENCHMARK COMPLETE!"
echo "================================================"
echo ""
echo "Generated files in 'results/' directory:"
ls -la results/
echo ""
echo "To view performance summary:"
echo "  cat results/performance_summary.txt"