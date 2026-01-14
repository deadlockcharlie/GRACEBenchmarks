#!/bin/bash
# collect-results.sh - Collect benchmark results from all GCP instances

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../config"
UTILS_DIR="$SCRIPT_DIR/utils"

source "$UTILS_DIR/ssh-helper.sh"
source "$UTILS_DIR/common.sh"

# Default parameters
REMOTE_RESULTS_DIR=""
LOCAL_RESULTS_DIR="$PROJECT_ROOT/Results/gcp_$(date +%Y%m%d_%H%M%S)"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --remote-dir)
            REMOTE_RESULTS_DIR="$2"
            shift 2
            ;;
        --local-dir)
            LOCAL_RESULTS_DIR="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Usage: $0 [--remote-dir PATH] [--local-dir PATH]"
            exit 1
            ;;
    esac
done

# Load instance IPs
load_instance_ips

# Find latest results directory if not specified
find_latest_results() {
    if [ -z "$REMOTE_RESULTS_DIR" ]; then
        log_info "Finding latest results directory..."
        
        local ip="${INSTANCE_IPS[us_east1]}"
        local USERNAME=$(whoami)
        
        REMOTE_RESULTS_DIR=$(ssh_exec "$ip" "ls -td /home/$USERNAME/grace/Results/*/ 2>/dev/null | head -1" || echo "")
        
        if [ -z "$REMOTE_RESULTS_DIR" ]; then
            log_error "No results directories found"
            echo "Run a benchmark first: ./run-benchmark.sh"
            exit 1
        fi
        
        log_info "Found: $REMOTE_RESULTS_DIR"
    fi
}

# Collect results from all instances
collect_all_results() {
    log_info "Collecting results from all GCP instances..."
    
    mkdir -p "$LOCAL_RESULTS_DIR"
    
    local USERNAME=$(whoami)
    local i=1
    
    for region in "${!INSTANCE_IPS[@]}"; do
        local ip="${INSTANCE_IPS[$region]}"
        log_info "Collecting from $region..."
        
        mkdir -p "$LOCAL_RESULTS_DIR/$region"
        
        # Download results directory
        scp $SSH_OPTS -r "$USERNAME@$ip:$REMOTE_RESULTS_DIR/*" \
            "$LOCAL_RESULTS_DIR/$region/" 2>/dev/null || true
        
        # Download container logs
        ssh_exec "$ip" "docker logs app$i > /tmp/app${i}.log 2>&1 || true"
        scp $SSH_OPTS "$USERNAME@$ip:/tmp/app${i}.log" \
            "$LOCAL_RESULTS_DIR/$region/" 2>/dev/null || true
        
        # Download system stats if available
        ssh_exec "$ip" "dmesg > /tmp/dmesg.log 2>&1 || true"
        scp $SSH_OPTS "$USERNAME@$ip:/tmp/dmesg.log" \
            "$LOCAL_RESULTS_DIR/$region/" 2>/dev/null || true
        
        log_info "$region complete ✓"
        i=$((i + 1))
    done
    
    log_info "All results collected ✓"
}

# Generate summary
generate_summary() {
    log_info "Generating summary..."
    
    cat > "$LOCAL_RESULTS_DIR/README.md" <<EOF
# GRACE GCP Benchmark Results

**Collection Date:** $(date)

## Instance Details

$(for region in "${!INSTANCE_IPS[@]}"; do
    echo "- **$region**: ${INSTANCE_IPS[$region]}"
done)

## Results Structure

\`\`\`
$(tree -L 2 "$LOCAL_RESULTS_DIR" 2>/dev/null || ls -R "$LOCAL_RESULTS_DIR")
\`\`\`

## Analysis

Run analysis scripts:
\`\`\`bash
cd $PROJECT_ROOT
python3 LatencyComparision.py
python3 ThroughputVsLatency.py
\`\`\`

EOF
    
    log_info "Summary generated: $LOCAL_RESULTS_DIR/README.md"
}

# Main execution
main() {
    log_info "=== GRACE Results Collection ==="
    
    find_latest_results
    collect_all_results
    generate_summary
    
    log_info "=== Collection Complete ==="
    log_info "Results saved to: $LOCAL_RESULTS_DIR"
    echo ""
    log_info "Next steps:"
    echo "  1. View results: cd $LOCAL_RESULTS_DIR"
    echo "  2. Run analysis: cd $PROJECT_ROOT && python3 LatencyComparision.py"
}

main "$@"
