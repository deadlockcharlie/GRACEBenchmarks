#!/bin/bash

# Benchmark multi-DC ReplicatedGDB deployment

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔥 Multi-DC Benchmark${NC}"
echo "======================================"
echo ""

DCS=("dc1" "dc2" "dc3" "dc4" "dc5" "dc6")
NUM_OPERATIONS=${NUM_OPERATIONS:-50}

echo "Configuration:"
echo "  Data Centers: 6"
echo "  Nodes per DC: 3"
echo "  Operations per DC: $NUM_OPERATIONS"
echo "  Total operations: $((NUM_OPERATIONS * 6))"
echo ""

# Function to benchmark a DC
benchmark_dc() {
    local dc=$1
    local port=$2
    local start_time=$(date +%s%N)
    local success=0
    local failed=0
    
    # Port forward
    kubectl port-forward -n "$dc" replicatedgdb-0 "$port":3000 &
    local pf_pid=$!
    sleep 2
    
    # Reset graph
    curl -s -X POST "http://localhost:${port}/reset" > /dev/null 2>&1 || true
    
    # Run operations
    for i in $(seq 1 $NUM_OPERATIONS); do
        vertex_id="${dc}-vertex-${i}"
        response=$(curl -s -w "%{http_code}" -o /dev/null -X POST \
            "http://localhost:${port}/api/addVertex" \
            -H "Content-Type: application/json" \
            -d "{\"id\":\"${vertex_id}\",\"labels\":[\"BenchmarkVertex\"],\"properties\":{\"name\":\"Node${i}\",\"dc\":\"${dc}\"}}")
        
        if [ "$response" = "200" ]; then
            ((success++))
        else
            ((failed++))
        fi
    done
    
   local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))
    local ops_per_sec=$(( success * 1000 / duration ))
    
    # Cleanup
    kill $pf_pid 2>/dev/null || true
    wait $pf_pid 2>/dev/null || true
    
    echo "$dc,$success,$failed,$duration,$ops_per_sec"
}

# Run benchmarks in parallel
echo -e "${YELLOW}Running benchmarks across all DCs...${NC}"
echo ""

declare -a pids
declare -a temp_files

for i in "${!DCS[@]}"; do
    dc="${DCS[$i]}"
    port=$((4000 + i))
    temp_file="/tmp/benchmark-${dc}.txt"
    temp_files+=("$temp_file")
    
    (benchmark_dc "$dc" "$port" > "$temp_file") &
    pids+=($!)
done

# Wait for all benchmarks to complete
for pid in "${pids[@]}"; do
    wait "$pid"
done

# Collect and display results
echo "======================================"
echo -e "${GREEN}Benchmark Results${NC}"
echo "======================================"
printf "%-10s %-10s %-10s %-15s %-15s\n" "DC" "Success" "Failed" "Duration (ms)" "Ops/sec"
echo "----------------------------------------------------------------------"

total_success=0
total_failed=0
total_duration=0

for temp_file in "${temp_files[@]}"; do
    if [ -f "$temp_file" ]; then
        result=$(cat "$temp_file")
        IFS=',' read -r dc success failed duration ops_per_sec <<< "$result"
        printf "%-10s %-10s %-10s %-15s %-15s\n" "$dc" "$success" "$failed" "$duration" "$ops_per_sec"
        
        total_success=$((total_success + success))
        total_failed=$((total_failed + failed))
        total_duration=$((total_duration + duration))
        
        rm "$temp_file"
    fi
done

echo "----------------------------------------------------------------------"
avg_duration=$((total_duration / 6))
total_ops_per_sec=$((total_success * 1000 / total_duration))

printf "%-10s %-10s %-10s %-15s %-15s\n" "TOTAL" "$total_success" "$total_failed" "$avg_duration" "$total_ops_per_sec"
echo ""

if [ $total_failed -eq 0 ]; then
    echo -e "${GREEN}✅ All operations completed successfully!${NC}"
else
    echo -e "${YELLOW}⚠️  $total_failed operations failed${NC}"
fi

echo ""
echo "Cross-DC Performance Metrics:"
echo "  • Total throughput: $total_ops_per_sec ops/sec across 6 DCs"
echo "  • Average per-DC throughput: $((total_ops_per_sec / 6)) ops/sec"
echo "  • Total vertices created: $total_success"
echo ""
echo "Next: Test cross-DC synchronization with ./scripts/test-cross-dc.sh"
