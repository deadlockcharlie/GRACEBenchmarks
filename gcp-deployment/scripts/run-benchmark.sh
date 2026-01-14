#!/bin/bash
# run-benchmark.sh - Run distributed benchmarks on GCP

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../config"
UTILS_DIR="$SCRIPT_DIR/utils"

source "$UTILS_DIR/ssh-helper.sh"
source "$UTILS_DIR/common.sh"

# Default parameters
DATASET="yeast"
DURATION=120
THREADS=64
WORKLOAD="workload_grace"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dataset)
            DATASET="$2"
            shift 2
            ;;
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --threads)
            THREADS="$2"
            shift 2
            ;;
        --workload)
            WORKLOAD="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Usage: $0 [--dataset NAME] [--duration SECONDS] [--threads COUNT] [--workload NAME]"
            exit 1
            ;;
    esac
done

# Load instance IPs
load_instance_ips

# Get first instance (will run YCSB from here)
YCSB_INSTANCE="${INSTANCE_IPS[us_east1]}"

# Get target application IP (first replica)
APP_HOST="${INSTANCE_IPS[us_east1]}"
APP_PORT=3000

# Prepare data on YCSB instance
prepare_benchmark_data() {
    log_info "Preparing benchmark data on YCSB instance..."
    
    local USERNAME=$(whoami)
    
    ssh_exec "$YCSB_INSTANCE" "cd /home/$USERNAME/grace/YCSB && \
        ./bin/ycsb load grace \
        -P workloads/$WORKLOAD \
        -p HOSTURI=http://$APP_HOST:$APP_PORT \
        -p insertcount=100000 \
        -threads 16"
    
    log_info "Data loaded ✓"
}

# Run benchmark
run_benchmark() {
    log_info "Running benchmark..."
    log_info "  Dataset: $DATASET"
    log_info "  Duration: $DURATION seconds"
    log_info "  Threads: $THREADS"
    log_info "  Target: http://$APP_HOST:$APP_PORT"
    
    local USERNAME=$(whoami)
    local results_dir="/home/$USERNAME/grace/Results/$(date +%Y%m%d_%H%M%S)_${DATASET}_${THREADS}threads"
    
    ssh_exec "$YCSB_INSTANCE" "mkdir -p $results_dir"
    
    ssh_exec "$YCSB_INSTANCE" "cd /home/$USERNAME/grace/YCSB && \
        ./bin/ycsb run grace \
        -P workloads/$WORKLOAD \
        -p HOSTURI=http://$APP_HOST:$APP_PORT \
        -p maxexecutiontime=$DURATION \
        -threads $THREADS \
        > $results_dir/benchmark_output.txt 2>&1"
    
    log_info "Benchmark completed ✓"
    log_info "Results stored in: $results_dir"
    
    echo "$results_dir"
}

# Collect results
collect_results() {
    local results_dir=$1
    local local_results="$PROJECT_ROOT/Results/gcp_$(basename $results_dir)"
    
    log_info "Collecting results from all instances..."
    
    mkdir -p "$local_results"
    
    local USERNAME=$(whoami)
    
    # Download from YCSB instance
    scp $SSH_OPTS -r "$USERNAME@$YCSB_INSTANCE:$results_dir/*" "$local_results/"
    
    # Download logs from all replicas
    local i=1
    for region in "${!INSTANCE_IPS[@]}"; do
        local ip="${INSTANCE_IPS[$region]}"
        mkdir -p "$local_results/$region"
        
        # Download container logs
        ssh_exec "$ip" "cd /home/$USERNAME/grace/ReplicatedGDB && \
            docker logs app$i > /tmp/app${i}.log 2>&1 || true"
        
        scp $SSH_OPTS "$USERNAME@$ip:/tmp/app${i}.log" \
            "$local_results/$region/" || true
        
        i=$((i + 1))
    done
    
    log_info "Results collected to: $local_results ✓"
}

# Main execution
main() {
    log_info "=== GRACE Distributed Benchmark on GCP ==="
    
    prepare_benchmark_data
    results_dir=$(run_benchmark)
    collect_results "$results_dir"
    
    log_info "=== Benchmark Complete ==="
    log_info "Results available locally in Results/ directory"
}

main "$@"
