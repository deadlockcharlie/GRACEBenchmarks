#!/bin/bash

# Test script for multiple ReplicatedGDB instances in Kubernetes

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

NAMESPACE=${NAMESPACE:-default}
BASE_PORT=${BASE_PORT:-30000}
NUM_INSTANCES=${NUM_INSTANCES:-3}

echo "🧪 Testing ReplicatedGDB instances..."
echo "======================================="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl not found${NC}"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}✗ Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

echo -e "${GREEN}✓ kubectl is configured${NC}\n"

# Check StatefulSet status
echo "📊 StatefulSet Status:"
kubectl get statefulset replicatedgdb -n $NAMESPACE 2>/dev/null || {
    echo -e "${RED}✗ StatefulSet 'replicatedgdb' not found${NC}"
    exit 1
}
echo ""

# Check Pods
echo "📦 Pod Status:"
kubectl get pods -l app=replicatedgdb -n $NAMESPACE
echo ""

# Test each instance
echo "🔍 Testing individual instances:"
echo "=================================="

SUCCESS_COUNT=0
FAIL_COUNT=0

for i in $(seq 0 $((NUM_INSTANCES - 1))); do
    POD_NAME="replicatedgdb-$i"
    PORT=$((BASE_PORT + i))
    
    echo -e "\n${YELLOW}Instance $i:${NC} $POD_NAME"
    echo "  Port: $PORT"
    
    # Check if pod exists and is ready
    POD_STATUS=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    
    if [ "$POD_STATUS" == "Running" ]; then
        echo -e "  ${GREEN}✓ Pod is running${NC}"
        
        # Test readiness endpoint
        echo -n "  Testing /ready endpoint... "
        if curl -sf http://localhost:$PORT/ready > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Ready${NC}"
            ((SUCCESS_COUNT++))
        else
            echo -e "${RED}✗ Not responding${NC}"
            echo "    Note: If using minikube, run 'minikube tunnel' in another terminal"
            ((FAIL_COUNT++))
        fi
    else
        echo -e "  ${RED}✗ Pod status: $POD_STATUS${NC}"
        ((FAIL_COUNT++))
    fi
done

echo ""
echo "======================================="
echo "Summary:"
echo -e "  ${GREEN}✓ Ready: $SUCCESS_COUNT${NC}"
echo -e "  ${RED}✗ Failed: $FAIL_COUNT${NC}"

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All instances are healthy!${NC}"
    exit 0
else
    echo -e "\n${YELLOW}⚠️  Some instances are not ready${NC}"
    exit 1
fi
