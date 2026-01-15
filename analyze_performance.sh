#!/bin/bash

# analyze_performance.sh - Analyze and compare serial vs parallel performance

set -e

echo "================================================"
echo "  PERFORMANCE ANALYSIS"
echo "================================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if results exist
if [ ! -f results/serial_performance.txt ] || [ ! -f results/parallel_performance.txt ]; then
    echo "Error: Performance files not found. Run serial and parallel scripts first."
    exit 1
fi

# Extract serial execution time
serial_time=$(grep "Execution Time:" results/serial_performance.txt | awk '{print $3}')

echo ""
echo -e "${BLUE}=== PERFORMANCE SUMMARY ==="
echo ""
echo -e "${YELLOW}SERIAL EXECUTION:${NC}"
echo "  Time: $serial_time seconds"
serial_words=$(grep "Total Words:" results/serial_performance.txt | awk '{print $3}')
echo "  Total Words: $serial_words"

echo ""
echo -e "${YELLOW}PARALLEL EXECUTION:${NC}"

# Read parallel performance data
echo "Processes | Time (s) | Speedup | Efficiency"
echo "----------|----------|---------|-----------"

# Arrays to store data for chart
declare -a processes_array
declare -a times_array
declare -a speedup_array
declare -a efficiency_array

while IFS= read -r line; do
    if [[ $line == Processes:* ]]; then
        np=${line#*: }
        processes_array+=("$np")
    elif [[ $line == *"Execution Time:"* ]]; then
        time=${line#*: }
        time=${time% seconds}
        times_array+=("$time")
        
        # Calculate speedup
        speedup=$(echo "scale=2; $serial_time / $time" | bc)
        speedup_array+=("$speedup")
        
        # Calculate efficiency
        efficiency=$(echo "scale=1; ($speedup / $np) * 100" | bc)
        efficiency_array+=("$efficiency")
        
        printf "%-10s| %-9s| %-8s| %s%%\n" "$np" "$time" "$speedup" "$efficiency"
    fi
done < results/parallel_performance.txt

echo ""

# Generate performance report
echo -e "${GREEN}=== PERFORMANCE REPORT ===${NC}" > results/performance_summary.txt
echo "Generated: $(date)" >> results/performance_summary.txt
echo "" >> results/performance_summary.txt

echo "Serial Execution:" >> results/performance_summary.txt
echo "  Time: $serial_time seconds" >> results/performance_summary.txt
echo "  Total Words: $serial_words" >> results/performance_summary.txt
echo "" >> results/performance_summary.txt

echo "Parallel Execution:" >> results/performance_summary.txt
echo "Processes | Time (s) | Speedup | Efficiency" >> results/performance_summary.txt
echo "----------|----------|---------|-----------" >> results/performance_summary.txt

for i in "${!processes_array[@]}"; do
    printf "%-10s| %-9s| %-8s| %s%%\n" \
        "${processes_array[$i]}" \
        "${times_array[$i]}" \
        "${speedup_array[$i]}" \
        "${efficiency_array[$i]}" >> results/performance_summary.txt
done

echo "" >> results/performance_summary.txt

# Find best configuration
best_index=0
best_speedup=${speedup_array[0]}
for i in "${!speedup_array[@]}"; do
    if (( $(echo "${speedup_array[$i]} > $best_speedup" | bc -l) )); then
        best_speedup=${speedup_array[$i]}
        best_index=$i
    fi
done

echo "Best Configuration:" >> results/performance_summary.txt
echo "  Processes: ${processes_array[$best_index]}" >> results/performance_summary.txt
echo "  Speedup: ${speedup_array[$best_index]}x" >> results/performance_summary.txt
echo "  Efficiency: ${efficiency_array[$best_index]}%" >> results/performance_summary.txt

# Display best configuration
echo ""
echo -e "${GREEN}=== BEST CONFIGURATION ==="
echo "  Processes: ${processes_array[$best_index]}"
echo "  Speedup: ${speedup_array[$best_index]}x (vs serial)"
echo "  Efficiency: ${efficiency_array[$best_index]}%"
echo -e "${NC}"

# Generate ASCII chart
echo ""
echo -e "${BLUE}=== SPEEDUP CHART ==="
max_speedup=$(printf "%s\n" "${speedup_array[@]}" | sort -nr | head -1)
scale=10

for i in "${!speedup_array[@]}"; do
    speedup=${speedup_array[$i]}
    np=${processes_array[$i]}
    
    # Calculate bar length
    bar_length=$(echo "scale=0; ($speedup / $max_speedup) * 40" | bc)
    
    # Create bar
    bar=""
    for ((j=0; j<bar_length; j++)); do
        bar="${bar}█"
    done
    
    printf "%-3s procs: %5.2fx |%-40s\n" "$np" "$speedup" "$bar"
done

echo -e "${NC}"

# Verify correctness
echo ""
echo -e "${YELLOW}=== CORRECTNESS CHECK ==="
serial_unique=$(grep "Unique Words:" results/serial_performance.txt | awk '{print $3}')

all_correct=true
for np in "${processes_array[@]}"; do
    if [ -f "results/parallel_results_${np}.txt" ]; then
        parallel_unique=$(grep "Unique words found:" "results/parallel_results_${np}.txt" | awk '{print $4}')
        if [ "$serial_unique" != "$parallel_unique" ]; then
            echo -e "${RED}  ERROR: Process $np - Unique word count mismatch!${NC}"
            echo "    Serial: $serial_unique, Parallel: $parallel_unique"
            all_correct=false
        else
            echo -e "${GREEN}  OK: Process $np - Unique word count matches${NC}"
        fi
    fi
done

if $all_correct; then
    echo -e "${GREEN}All parallel results match serial results!${NC}"
else
    echo -e "${RED}Warning: Some parallel results differ from serial!${NC}"
fi

echo ""
echo -e "${BLUE}=== REPORT SAVED ==="
echo "Performance summary: results/performance_summary.txt"
echo -e "${NC}"

# Display report
echo ""
echo "Would you like to view the full report? (y/n)"
read -p "Choice: " view_report
if [[ $view_report == "y" || $view_report == "Y" ]]; then
    echo ""
    cat results/performance_summary.txt
fi