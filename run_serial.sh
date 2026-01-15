#!/bin/bash

# run_serial.sh - Run serial word count and measure performance

set -e

echo "================================================"
echo "  SERIAL WORD COUNT EXECUTION"
echo "================================================"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if serial program exists
if [ ! -f Serial_Version ]; then
    echo "Error: Serial_Version not found. Run setup.sh first."
    exit 1
fi

# Create results directory
mkdir -p results
mkdir -p logs

echo ""
echo "Available input files:"
ls -la input*.txt large_input.txt 2>/dev/null || echo "No input files found"

echo ""
echo "Select files to process:"
echo "1. Small files only (input1.txt input2.txt input3.txt)"
echo "2. Large file only (large_input.txt)"
echo "3. All files"
echo "4. Custom selection"
read -p "Enter choice (1-4): " choice

case $choice in
    1)
        FILES="input1.txt input2.txt input3.txt"
        ;;
    2)
        FILES="large_input.txt"
        ;;
    3)
        FILES="input1.txt input2.txt input3.txt large_input.txt"
        ;;
    4)
        echo "Enter filenames separated by spaces:"
        read -p "Files: " FILES
        ;;
    *)
        echo "Invalid choice, using small files."
        FILES="input1.txt input2.txt input3.txt"
        ;;
esac

echo ""
echo "Processing files: $FILES"

# Check if files exist
for file in $FILES; do
    if [ ! -f "$file" ]; then
        echo "Error: File $file not found!"
        exit 1
    fi
done

# Run serial version with time measurement
echo ""
echo "Running serial word count..."
echo "----------------------------------------"

# Measure execution time
start_time=$(date +%s.%N)

# Run the program and capture output
./Serial_Version $FILES > logs/serial_output.log 2>&1

end_time=$(date +%s.%N)

# Calculate execution time
execution_time=$(echo "$end_time - $start_time" | bc)

# Extract results from output
total_words=$(grep "Total words processed:" logs/serial_output.log | awk '{print $4}')
unique_words=$(grep "Unique words found:" logs/serial_output.log | awk '{print $4}')

# Save serial results
cp serial_results.txt results/serial_results.txt 2>/dev/null || true

# Save performance data
echo "# Serial Execution Results" > results/serial_performance.txt
echo "Timestamp: $(date)" >> results/serial_performance.txt
echo "Files: $FILES" >> results/serial_performance.txt
echo "Execution Time: $execution_time seconds" >> results/serial_performance.txt
echo "Total Words: $total_words" >> results/serial_performance.txt
echo "Unique Words: $unique_words" >> results/serial_performance.txt

echo ""
echo -e "${GREEN}=== SERIAL EXECUTION COMPLETE ==="
echo "Execution Time: ${execution_time} seconds"
echo "Total Words Processed: $total_words"
echo "Unique Words Found: $unique_words"
echo -e "Results saved to: results/serial_results.txt${NC}"
echo "Performance data: results/serial_performance.txt"
echo "Full output: logs/serial_output.log"

# Display top 10 words
echo ""
echo -e "${BLUE}=== TOP 10 WORDS (SERIAL) ==="
echo "Word                Count"
echo "----                -----"
if [ -f results/serial_results.txt ]; then
    grep -A 12 "WORD FREQUENCY TABLE" results/serial_results.txt | tail -n +3 | head -12
fi
echo -e "${NC}"
