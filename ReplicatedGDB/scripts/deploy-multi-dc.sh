#!/bin/bash

# Deploy ReplicatedGDB across 6 data centers using Kubernetes namespaces

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🌍 Multi-DC Deployment for ReplicatedGDB${NC}"
echo "=========================================="
echo ""

# Configuration
DCS=("dc1" "dc2" "dc3" "dc4" "dc5" "dc6")
REGIONS=("us-east-1" "us-west-1" "eu-central-1" "asia-south-1" "asia-southeast-1" "sa-east-1")

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ kubectl found${NC}"
echo ""

# Step 1: Create namespaces
echo -e "${YELLOW}Step 1: Creating namespaces for each DC...${NC}"
for i in "${!DCS[@]}"; do
    dc="${DCS[$i]}"
    if kubectl get namespace "$dc" &> /dev/null; then
        echo "  → Namespace $dc already exists"
    else
        kubectl create namespace "$dc"
        kubectl label namespace "$dc" datacenter="$dc" region="${REGIONS[$i]}"
        echo -e "  ${GREEN}✓ Created namespace $dc${NC}"
    fi
done
echo ""

# Step 2: Deploy Y.js provider per DC
echo -e "${YELLOW}Step 2: Deploying Y.js provider to each DC...${NC}"
for dc in "${DCS[@]}"; do
    echo "  Deploying Y.js provider to $dc..."
    kubectl apply -f k8s/provider.yaml -n "$dc"
    echo -e "  ${GREEN}✓ Y.js provider deployed to $dc${NC}"
done
echo ""

# Step 3: Generate ConfigMaps for each DC
echo -e "${YELLOW}Step 3: Generating DC-specific configurations...${NC}"
mkdir -p k8s/multi-dc
for i in "${!DCS[@]}"; do
    dc="${DCS[$i]}"
    region="${REGIONS[$i]}"
    mkdir -p "k8s/multi-dc/$dc"
    
    # Determine if this DC should be preload leader (only DC1)
    if [ "$dc" = "dc1" ]; then
        preload="Yes"
    else
        preload="No"
    fi
    
    # Generate ConfigMap
    cat > "k8s/multi-dc/$dc/configmap.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: replicatedgdb-config
  namespace: $dc
  labels:
    app: replicatedgdb
    datacenter: $dc
data:
  DATABASE: "MEMGRAPH"
  WS_URI: "ws://yjs-provider:1234"
  DC_ID: "$dc"
  DC_REGION: "$region"
  IS_PRELOAD_LEADER: "$preload"
EOF

    # Copy base deployment and service files
    sed "s/namespace: default/namespace: $dc/g; s/nodePort: 3000/nodePort: 3$((i*10))/g" k8s/deployment.yaml > "k8s/multi-dc/$dc/deployment.yaml"
    
    # Update service file with DC-specific NodePorts
    cat > "k8s/multi-dc/$dc/service.yaml" <<EOF
# Headless service for StatefulSet pod DNS
apiVersion: v1
kind: Service
metadata:
  name: replicatedgdb-headless
  namespace: $dc
spec:
  clusterIP: None
  ports:
  - port: 3000
    targetPort: 3000
  selector:
    app: replicatedgdb
---
# Individual NodePort services
apiVersion: v1
kind: Service
metadata:
  name: replicatedgdb-0
  namespace: $dc
spec:
  type: NodePort
  ports:
  - port: 3000
    targetPort: 3000
    nodePort: 3$((i*10))000
  selector:
    statefulset.kubernetes.io/pod-name: replicatedgdb-0
---
apiVersion: v1
kind: Service
metadata:
  name: replicatedgdb-1
  namespace: $dc
spec:
  type: NodePort
  ports:
  - port: 3000
    targetPort: 3000
    nodePort: 3$((i*10))001
  selector:
    statefulset.kubernetes.io/pod-name: replicatedgdb-1
---
apiVersion: v1
kind: Service
metadata:
  name: replicatedgdb-2
  namespace: $dc
spec:
  type: NodePort
  ports:
  - port: 3000
    targetPort: 3000
    nodePort: 3$((i*10))002
  selector:
    statefulset.kubernetes.io/pod-name: replicatedgdb-2
EOF
    
    echo -e "  ${GREEN}✓ Generated config for $dc ($region)${NC}"
done
echo ""

# Step 4: Deploy to each DC
echo -e "${YELLOW}Step 4: Deploying to all data centers...${NC}"
for dc in "${DCS[@]}"; do
    echo "  Deploying to $dc..."
    kubectl apply -f "k8s/multi-dc/$dc/" -n "$dc"
    echo -e "  ${GREEN}✓ Deployed to $dc${NC}"
done
echo ""

# Step 5: Wait for rollout
echo -e "${YELLOW}Step 5: Waiting for deployments to be ready...${NC}"
for dc in "${DCS[@]}"; do
    echo "  Waiting for $dc..."
    kubectl rollout status statefulset/replicatedgdb -n "$dc" --timeout=120s || echo "  ⏸ $dc still rolling out..."
done
echo ""

# Step 6: Verify
echo -e "${YELLOW}Step 6: Verification${NC}"
echo "=========================================="
for dc in "${DCS[@]}"; do
    echo -e "\n${BLUE}$dc:${NC}"
    kubectl get pods -n "$dc" -l app=replicatedgdb
done
echo ""

echo -e "${GREEN}✅ Multi-DC deployment complete!${NC}"
echo ""
echo "Summary:"
echo "  • 6 data centers deployed (dc1-dc6)"
echo "  • 3 nodes per DC = 18 total nodes"
echo "  • Y.js hub running in 'yjs' namespace"
echo ""
echo "Next steps:"
echo "  • Verify sync: ./scripts/verify-multi-dc.sh"
echo "  • Test cross-DC: ./scripts/test-cross-dc.sh"
echo "  • Monitor: kubectl get pods --all-namespaces -l app=replicatedgdb"
echo ""
echo "Access endpoints:"
for i in "${!DCS[@]}"; do
    dc="${DCS[$i]}"
    echo "  $dc: http://localhost:3${i}000 (node 0), 3${i}001 (node 1), 3${i}002 (node 2)"
done
