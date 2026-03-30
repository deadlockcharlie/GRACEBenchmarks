#!/bin/bash

# Verify multi-DC deployment status

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}📊 Multi-DC Deployment Verification${NC}"
echo "======================================"
echo ""

DCS=("dc1" "dc2" "dc3" "dc4" "dc5" "dc6")

# Check Y.js hub
echo -e "${YELLOW}Y.js WebSocket Hub:${NC}"
if kubectl get deployment yjs-hub -n yjs &> /dev/null; then
    HUB_STATUS=$(kubectl get deployment yjs-hub -n yjs -o jsonpath='{.status.availableReplicas}' 2>/dev/null || echo "0")
    if [ "$HUB_STATUS" = "1" ]; then
        echo -e "  ${GREEN}✓ Running${NC}"
    else
        echo -e "  ${RED}✗ Not ready (replicas: $HUB_STATUS/1)${NC}"
    fi
else
    echo -e "  ${RED}✗ Not deployed${NC}"
fi
echo ""

# Check each DC
TOTAL_NODES=0
READY_NODES=0

for dc in "${DCS[@]}"; do
    echo -e "${YELLOW}Data Center: $dc${NC}"
    
    # Check namespace
    if ! kubectl get namespace "$dc" &> /dev/null; then
        echo -e "  ${RED}✗ Namespace not found${NC}"
        continue
    fi
    
    # Check StatefulSet
    if kubectl get statefulset replicatedgdb -n "$dc" &> /dev/null; then
        REPLICAS=$(kubectl get statefulset replicatedgdb -n "$dc" -o jsonpath='{.spec.replicas}')
        READY=$(kubectl get statefulset replicatedgdb -n "$dc" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        
        echo "  StatefulSet: $READY/$REPLICAS ready"
        TOTAL_NODES=$((TOTAL_NODES + REPLICAS))
        READY_NODES=$((READY_NODES + READY))
        
        # List pods
        kubectl get pods -n "$dc" -l app=replicatedgdb --no-headers | while read line; do
            POD_NAME=$(echo $line | awk '{print $1}')
            POD_STATUS=$(echo $line | awk '{print $3}')
            if [ "$POD_STATUS" = "Running" ]; then
                echo -e "    ${GREEN}✓${NC} $POD_NAME"
            else
                echo -e "    ${RED}✗${NC} $POD_NAME ($POD_STATUS)"
            fi
        done
    else
        echo -e "  ${RED}✗ StatefulSet not found${NC}"
    fi
    
    # Check services
    SVC_COUNT=$(kubectl get svc -n "$dc" -l app=replicatedgdb --no-headers 2>/dev/null | wc -l | tr -d ' ')
    echo "  Services: $SVC_COUNT"
    
    echo ""
done

# Summary
echo "======================================"
echo -e "${BLUE}Summary:${NC}"
echo "  Total nodes expected: ${TOTAL_NODES}"
echo "  Nodes ready: ${READY_NODES}"
echo ""

if [ $READY_NODES -eq $TOTAL_NODES ] && [ $TOTAL_NODES -gt 0 ]; then
    echo -e "${GREEN}✅ All nodes are ready!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Test cross-DC sync: ./scripts/test-cross-dc.sh"
    echo "  2. Run benchmark: ./scripts/benchmark-multi-dc.sh"
    echo "  3. Monitor: kubectl get pods --all-namespaces -l app=replicatedgdb -w"
else
    echo -e "${YELLOW}⚠️  Some nodes are not ready yet${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  • Check pod logs: kubectl logs -n <dc> replicatedgdb-0"
    echo "  • Describe pod: kubectl describe pod -n <dc> replicatedgdb-0"
    echo "  • Check events: kubectl get events -n <dc> --sort-by='.lastTimestamp'"
fi
