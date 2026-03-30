#!/bin/bash

# Simple benchmark script for ReplicatedGDB instances
# Tests basic operations across all instances

set -e

# Configuration
BASE_PORT=${BASE_PORT:-30000}
NUM_INSTANCES=${NUM_INSTANCES:-3}
NUM_OPERATIONS=${NUM_OPERATIONS:-100}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔥 ReplicatedGDB Benchmark${NC}"
echo "======================================"
echo "Instances: $NUM_INSTANCES"
echo "Operations per instance: $NUM_OPERATIONS"
echo "======================================"
echo ""

# Function to add vertices to an instance
benchmark_add_vertex() {
    local instance=$1
    local port=$((BASE_PORT + instance))
    local start_time=$(date +%s%N)
    local success=0
    local failed=0
    
    for i in $(seq 1 $NUM_OPERATIONS); do
        vertex_id="vertex-${instance}-${i}"
        response=$(curl -s -w "%{http_code}" -o /dev/null -X POST \
            "http://localhost:${port}/api/addVertex" \
            -H "Content-Type: application/json" \
            -d "{\"id\":\"${vertex_id}\",\"labels\":[\"TestVertex\"],\"properties\":{\"name\":\"Node${i}\",\"instance\":${instance}}}")
        
        if [ "$response" = "200" ]; then
            ((success++))
        else
            ((failed++))
        fi
    done
    
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 )) # Convert to ms
    local ops_per_sec=$(( success * 1000 / duration ))
    
    echo "$instance,$success,$failed,$duration,$ops_per_sec"
}

# Function to benchmark an instance
benchmark_instance() {
    local instance=$1
    local port=$((BASE_PORT + instance))
    
    echo -e "${YELLOW}Testing instance $instance on port $port...${NC}"
    
    # Test connectivity
    if ! curl -sf "http://localhost:${port}/ready" > /dev/null 2>&1; then
        echo -e "${RED}✗ Instance $instance is not ready${NC}"
        return 1
    fi
    
    # Reset graph
    curl -s -X POST "http://localhost:${port}/reset" > /dev/null
    
    # Benchmark add vertex operations
    result=$(benchmark_add_vertex $instance)
    echo "$result"
}

# Run benchmarks
echo "Starting benchmarks..."
echo ""

declare -a results

for i in $(seq 0 $((NUM_INSTANCES - 1))); do
    result=$(benchmark_instance $i)
    results[$i]="$result"
done

# Display results
echo ""
echo "======================================"
echo -e "${GREEN}Benchmark Results${NC}"
echo "======================================"
printf "%-10s %-10s %-10s %-15s %-15s\n" "Instance" "Success" "Failed" "Duration (ms)" "Ops/sec"
echo "----------------------------------------------------------------------"

total_success=0
total_failed=0
total_duration=0

for i in $(seq 0 $((NUM_INSTANCES - 1))); do
    IFS=',' read -r inst success failed duration ops_per_sec <<< "${results[$i]}"
    printf "%-10s %-10s %-10s %-15s %-15s\n" "$inst" "$success" "$failed" "$duration" "$ops_per_sec"
    
    total_success=$((total_success + success))
    total_failed=$((total_failed + failed))
    total_duration=$((total_duration + duration))
done

echo "----------------------------------------------------------------------"
avg_duration=$((total_duration / NUM_INSTANCES))
total_ops_per_sec=$((total_success * 1000 / total_duration))

printf "%-10s %-10s %-10s %-15s %-15s\n" "TOTAL" "$total_success" "$total_failed" "$avg_duration" "$total_ops_per_sec"
echo ""

if [ $total_failed -eq 0 ]; then
    echo -e "${GREEN}✅ All operations completed successfully!${NC}"
else
    echo -e "${YELLOW}⚠️  Some operations failed${NC}"
fi

echo ""
echo "💡 Tips:"
echo "  - Increase operations: NUM_OPERATIONS=1000 ./scripts/benchmark.sh"
echo "  - Test more instances: NUM_INSTANCES=5 ./scripts/benchmark.sh"
echo "  - For production benchmarking on GKE, use tools like Apache JMeter or k6.io"
