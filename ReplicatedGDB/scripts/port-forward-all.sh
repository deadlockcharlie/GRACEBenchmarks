#!/bin/bash

# Port forward all ReplicatedGDB instances (app + Memgraph Lab) to different local ports
# This script runs port-forwarding in the background for all instances

set -e

NAMESPACE=${NAMESPACE:-default}
APP_BASE_PORT=${APP_BASE_PORT:-8080}
LAB_BASE_PORT=${LAB_BASE_PORT:-3000}
NUM_INSTANCES=${NUM_INSTANCES:-3}

echo "🔌 Setting up port forwarding for all instances..."
echo "=================================================="

# Kill any existing port-forward processes
pkill -f "kubectl port-forward replicatedgdb-" 2>/dev/null || true
sleep 1

# Port forward each instance (both app and lab)
for i in $(seq 0 $((NUM_INSTANCES - 1))); do
    POD_NAME="replicatedgdb-$i"
    APP_LOCAL_PORT=$((APP_BASE_PORT + i))
    LAB_LOCAL_PORT=$((LAB_BASE_PORT + i))
    
    echo "Forwarding $POD_NAME:"
    echo "  - App:  localhost:$APP_LOCAL_PORT -> container:8080"
    echo "  - Lab:  localhost:$LAB_LOCAL_PORT -> container:3000"
    
    # Forward app port
    kubectl port-forward -n $NAMESPACE $POD_NAME $APP_LOCAL_PORT:8080 &
    APP_PID=$!
    
    # Forward lab port  
    kubectl port-forward -n $NAMESPACE $POD_NAME $LAB_LOCAL_PORT:3000 &
    LAB_PID=$!
    
    echo "  PIDs: App=$APP_PID, Lab=$LAB_PID"
    echo ""
    
    sleep 1
done

echo "✓ Port forwarding active:"
echo ""
echo "Node.js App:"
for i in $(seq 0 $((NUM_INSTANCES - 1))); do
    APP_LOCAL_PORT=$((APP_BASE_PORT + i))
    echo "  Instance $i: http://localhost:$APP_LOCAL_PORT"
done

echo ""
echo "Memgraph Lab:"
for i in $(seq 0 $((NUM_INSTANCES - 1))); do
    LAB_LOCAL_PORT=$((LAB_BASE_PORT + i))
    echo "  Instance $i: http://localhost:$LAB_LOCAL_PORT"
done

echo ""
echo "Press Ctrl+C to stop all port forwards"
echo ""

# Wait for user interrupt
trap "echo ''; echo 'Stopping all port forwards...'; pkill -f 'kubectl port-forward replicatedgdb-'; exit 0" INT

# Keep script running
while true; do
    sleep 1
done
