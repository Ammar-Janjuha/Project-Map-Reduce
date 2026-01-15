#!/bin/bash

# run_parallel.sh - Run parallel word count with different process counts

set -e

echo "================================================"
echo "  PARALLEL WORD COUNT EXECUTION"
echo "================================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if parallel program exists
if [ ! -f Parallel_Version ]; then
    echo "Error: Parallel_Version not found. Run setup.sh first."
    exit 1
fi

# Check MPI
if ! command -v mpirun &> /dev/null; then
    echo "Error: mpirun not found. Install MPI first."
    exit 1
fi

# Create directories
mkdir -p results
mkdir -p logs

echo ""
echo "Available input files:"
ls -la input*.txt large_input.txt 2>/dev/null || echo "No input files found"

echo ""
echo "Select files to process:"
echo "1. Small files only (input1.txt input2.txt)"
echo "2. Large file only (large_input.txt)"
echo "3. All files"
echo "4. Custom selection"
read -p "Enter choice (1-4): " choice

case $choice in
    1)
        FILES="input1.txt input2.txt"
        ;;
    2)
        FILES="large_input.txt"
        ;;
    3)
        FILES="input1.txt input2.txt large_input.txt"
        ;;
    4)
        echo "Enter filenames separated by spaces:"
        read -p "Files: " FILES
        ;;
    *)
        echo "Invalid choice, using small files."
        FILES="input1.txt input2.txt"
        ;;
esac

echo ""
echo "Select number of processes to test:"
echo "1. 2 processes only"
echo "2. 4 processes only"
echo "3. 2, 4, and 8 processes"
echo "4. Custom process counts"
read -p "Enter choice (1-4): " proc_choice

case $proc_choice in
    1)
        PROCESSES="2"
        ;;
    2)
        PROCESSES="4"
        ;;
    3)
        PROCESSES="2 4 8"
        ;;
    4)
        echo "Enter number of processes separated by spaces:"
        read -p "Processes: " PROCESSES
        ;;
    *)
        PROCESSES="2 4"
        ;;
esac

echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Files: $FILES"
echo "  Process counts to test: $PROCESSES"
echo ""

# Initialize performance file
echo "# Parallel Execution Results" > results/parallel_performance.txt
echo "Timestamp: $(date)" >> results/parallel_performance.txt
echo "Files: $FILES" >> results/parallel_performance.txt
echo "" >> results/parallel_performance.txt

# Run for each process count
for np in $PROCESSES; do
    echo "----------------------------------------"
    echo -e "${YELLOW}Testing with $np processes...${NC}"
    
    # Measure execution time
    start_time=$(date +%s.%N)
    
    # Run parallel program
    mpirun -np $np ./Parallel_Version $FILES > "logs/parallel_${np}_output.log" 2>&1
    
    end_time=$(date +%s.%N)
    
    # Calculate execution time
    execution_time=$(echo "$end_time - $start_time" | bc)
    
    # Extract results
    total_words=$(grep "Total words processed:" "logs/parallel_${np}_output.log" | tail -1 | awk '{print $5}')
    unique_words=$(grep "Unique words found:" "logs/parallel_${np}_output.log" | tail -1 | awk '{print $4}')
    
    # Save results
    cp parallel_results.txt "results/parallel_results_${np}.txt" 2>/dev/null || true
    
    # Save performance data
    echo "Processes: $np" >> results/parallel_performance.txt
    echo "  Execution Time: $execution_time seconds" >> results/parallel_performance.txt
    echo "  Total Words: $total_words" >> results/parallel_performance.txt
    echo "  Unique Words: $unique_words" >> results/parallel_performance.txt
    echo "" >> results/parallel_performance.txt
    
    echo -e "${GREEN}  Execution Time: $execution_time seconds${NC}"
    echo "  Total Words: $total_words"
    echo "  Unique Words: $unique_words"
done

echo ""
echo "----------------------------------------"
echo -e "${GREEN}=== PARALLEL EXECUTION COMPLETE ==="
echo ""
echo "Results saved:"
for np in $PROCESSES; do
    echo "  $np processes: results/parallel_results_${np}.txt"
done
echo ""
echo "Performance data: results/parallel_performance.txt"
echo "Log files: logs/parallel_*_output.log${NC}"

# Display comparison
echo ""
echo -e "${BLUE}=== EXECUTION TIME COMPARISON ==="
echo "Processes | Time (seconds)"
echo "----------|---------------"
cat results/parallel_performance.txt | grep -A 1 "Processes:" | while read line1; do
    read line2
    if [[ $line1 == Processes:* ]]; then
        np=${line1#*: }
        time=$(echo "$line2" | awk '{print $3}')
        printf "%-10s| %s\n" "$np" "$time"
    fi
done
echo -e "${NC}"
