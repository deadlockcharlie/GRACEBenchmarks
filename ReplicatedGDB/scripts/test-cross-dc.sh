#!/bin/bash

# Verify cross-DC synchronization for ReplicatedGDB

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Cross-DC Synchronization Test${NC}"
echo "======================================"
echo ""

DCS=("dc1" "dc2" "dc3" "dc4" "dc5" "dc6")
TEST_VERTEX_ID="crossdc-test-$(date +%s)"

# Step 1: Write to DC1
echo -e "${YELLOW}Step 1: Writing test vertex to DC1...${NC}"

# Port forward DC1 node 0 temporarily
kubectl port-forward -n dc1 replicatedgdb-0 3000:3000 &
PF_PID=$!
sleep 2

# Add test vertex
RESPONSE=$(curl -s -X POST http://localhost:3000/api/addVertex \
  -H "Content-Type: application/json" \
  -d "{\"id\":\"$TEST_VERTEX_ID\",\"labels\":[\"CrossDCTest\"],\"properties\":{\"origin\":\"dc1\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}")

kill $PF_PID 2>/dev/null || true
wait $PF_PID 2>/dev/null || true

echo -e "  ${GREEN}✓ Test vertex created in DC1${NC}"
echo "  Vertex ID: $TEST_VERTEX_ID"
echo ""

# Step 2: Wait for sync
echo -e "${YELLOW}Step 2: Waiting for cross-DC synchronization (10 seconds)...${NC}"
sleep 10
echo ""

# Step 3: Verify in all other DCs
echo -e "${YELLOW}Step 3: Verifying sync across all DCs...${NC}"
SUCCESS_COUNT=0
FAIL_COUNT=0

for dc in "${DCS[@]}"; do
    echo -n "  Checking $dc... "
    
    # Port forward this DC
    kubectl port-forward -n "$dc" replicatedgdb-0 3001:3000 &
    PF_PID=$!
    sleep 2
    
    # Try to get the vertex
    FOUND=$(curl -s http://localhost:3001/api/getVertex?id=$TEST_VERTEX_ID | jq -r '.id' 2>/dev/null || echo "")
    
    kill $PF_PID 2>/dev/null || true
    wait $PF_PID 2>/dev/null || true
    
    if [ "$FOUND" = "$TEST_VERTEX_ID" ]; then
        echo -e "${GREEN}✓ Synced${NC}"
        ((SUCCESS_COUNT++))
    else
        echo -e "${RED}✗ Not found${NC}"
        ((FAIL_COUNT++))
    fi
done

echo ""
echo "======================================"
echo "Results:"
echo -e "  ${GREEN}✓ Synced: $SUCCESS_COUNT DCs${NC}"
echo -e "  ${RED}✗ Failed: $FAIL_COUNT DCs${NC}"

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "\n${GREEN}🎉 Cross-DC synchronization working perfectly!${NC}"
    exit 0
else
    echo -e "\n${YELLOW}⚠️  Some DCs failed to sync. Check Y.js hub connectivity.${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check Y.js hub: kubectl get pods -n yjs"
    echo "  2. Check logs: kubectl logs -n yjs -l app=yjs-hub"
    echo "  3. Check connectivity: kubectl exec -n dc2 replicatedgdb-0 -- nslookup yjs-hub.yjs.svc.cluster.local"
    exit 1
fi
