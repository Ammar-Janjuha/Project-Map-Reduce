#!/bin/bash

# setup.sh - Master setup script for MapReduce Word Count Project

set -e  # Exit on error

echo "================================================"
echo "  MapReduce Word Count - Complete Setup"
echo "================================================"

# Create directories
mkdir -p results
mkdir -p logs

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check for MPI
check_mpi() {
    if ! command -v mpicc &> /dev/null; then
        print_warning "MPI (mpicc) not found!"
        echo "Please install MPI:"
        echo "  Ubuntu/Debian: sudo apt-get install mpich"
        echo "  CentOS/RHEL: sudo yum install mpich-devel"
        echo "  macOS: brew install mpich"
        exit 1
    fi
    print_success "MPI found: $(mpicc --version | head -1)"
}

# Compile programs
compile_programs() {
    print_info "Compiling serial version..."
    gcc -o Serial_Version Serial_Version.c -lm -O2
    if [ $? -eq 0 ]; then
        print_success "Serial version compiled successfully!"
    else
        print_error "Failed to compile serial version!"
        exit 1
    fi
    
    print_info "Compiling parallel version..."
    mpicc -o Parallel_Version Parallel_Version.c -lm -O2
    if [ $? -eq 0 ]; then
        print_success "Parallel version compiled successfully!"
    else
        print_error "Failed to compile parallel version!"
        exit 1
    fi
}

# Create sample files if they don't exist
create_sample_files() {
    if [ ! -f input1.txt ] || [ ! -f input2.txt ]; then
        print_info "Creating sample input files..."
        
        cat > input1.txt << 'EOF'
The MapReduce programming model processes large datasets with parallel algorithms.
Hadoop implements MapReduce for distributed computing across clusters.
The Map phase filters and sorts data, while Reduce phase aggregates results.
Parallel computing significantly improves performance for big data tasks.
EOF

        cat > input2.txt << 'EOF'
MPI (Message Passing Interface) enables parallel programming on distributed systems.
MPI functions include point-to-point communication and collective operations.
MPI programs can run on supercomputers and computer clusters.
The MPI standard defines language bindings for C, C++, and Fortran.
EOF

        cat > large_input.txt << 'EOF'
Performance benchmarking measures system behavior under workload.
Scalability testing evaluates performance with increasing resources.
Efficiency analysis compares speedup to theoretical maximum.
Amdahls Law describes theoretical speedup from parallelization.
Parallel overhead includes communication and synchronization costs.
Strong scaling measures speedup with fixed problem size.
Weak scaling measures performance with scaled problem size.
Communication patterns affect parallel algorithm efficiency.
Load imbalance reduces parallel efficiency significantly.
Parallel slowdown occurs when overhead exceeds benefits.
EOF
        
        print_success "Sample files created: input1.txt, input2.txt, large_input.txt"
    else
        print_info "Sample files already exist."
    fi
}

# Main execution
main() {
    echo ""
    print_info "Starting setup process..."
    
    # Check MPI for parallel version
    check_mpi
    
    # Compile programs
    compile_programs
    
    # Create sample files
    create_sample_files
    
    # Make scripts executable
    chmod +x run_serial.sh run_parallel.sh analyze_performance.sh
    
    echo ""
    echo "================================================"
    print_success "Setup completed successfully!"
    echo "================================================"
    echo ""
    echo "Available scripts:"
    echo "  1. ./run_serial.sh          - Run serial version only"
    echo "  2. ./run_parallel.sh        - Run parallel version only"
    echo "  3. ./analyze_performance.sh - Analyze performance"
    echo ""
    echo "To run everything sequentially:"
    echo "  ./run_serial.sh && ./run_parallel.sh && ./analyze_performance.sh"
    echo ""
}

# Run main function
main "$@"
