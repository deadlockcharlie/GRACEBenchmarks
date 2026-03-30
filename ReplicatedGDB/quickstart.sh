#!/bin/bash

# Quick start script for deploying ReplicatedGDB to local Kubernetes

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 ReplicatedGDB Quick Start${NC}"
echo "=============================="
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker not found. Please install Docker.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker found${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl not found. Please install kubectl.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ kubectl found${NC}"

if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}✗ Cannot connect to Kubernetes cluster.${NC}"
    echo "  Please start your cluster (minikube start, or enable Kubernetes in Docker Desktop)"
    exit 1
fi
echo -e "${GREEN}✓ Kubernetes cluster accessible${NC}"
echo ""

# Detect cluster type
if kubectl config current-context | grep -q "minikube"; then
    CLUSTER_TYPE="minikube"
    echo -e "${YELLOW}Detected Minikube cluster${NC}"
elif kubectl config current-context | grep -q "kind"; then
    CLUSTER_TYPE="kind"
    echo -e "${YELLOW}Detected Kind cluster${NC}"
else
    CLUSTER_TYPE="docker-desktop"
    echo -e "${YELLOW}Detected Docker Desktop or other cluster${NC}"
fi
echo ""

# Build image
echo "🔨 Building Docker images..."
docker build -t replicatedgdb:latest . || {
    echo -e "${RED}✗ Docker build failed${NC}"
    exit 1
}
echo -e "${GREEN}✓ ReplicatedGDB image built successfully${NC}"

# Build provider image
echo "🔨 Building Y.js provider image..."
docker build -f ../ProviderDockerfile -t yjs-provider:latest ../ || {
    echo -e "${RED}✗ Provider build failed${NC}"
    exit 1
}
echo -e "${GREEN}✓ Y.js provider image built successfully${NC}"
echo ""

# Load image into cluster if needed
if [ "$CLUSTER_TYPE" = "minikube" ]; then
    echo "📦 Loading images into Minikube..."
    minikube image load replicatedgdb:latest || {
        echo -e "${RED}✗ Failed to load ReplicatedGDB image into Minikube${NC}"
        exit 1
    }
    minikube image load yjs-provider:latest || {
        echo -e "${RED}✗ Failed to load provider image into Minikube${NC}"
        exit 1
    }
    echo -e "${GREEN}✓ Images loaded into Minikube${NC}"
    echo ""
elif [ "$CLUSTER_TYPE" = "kind" ]; then
    echo "📦 Loading images into Kind..."
    kind load docker-image replicatedgdb:latest || {
        echo -e "${RED}✗ Failed to load ReplicatedGDB image into Kind${NC}"
        exit 1
    }
    kind load docker-image yjs-provider:latest || {
        echo -e "${RED}✗ Failed to load provider image into Kind${NC}"
        exit 1
    }
    echo -e "${GREEN}✓ Images loaded into Kind${NC}"
    echo ""
fi

# Deploy to Kubernetes
echo "☸️  Deploying to Kubernetes..."
kubectl apply -f k8s/ || {
    echo -e "${RED}✗ Deployment failed${NC}"
    exit 1
}
echo -e "${GREEN}✓ Deployed successfully${NC}"
echo ""

# Wait for pods to be ready
echo "⏳ Waiting for pods to be ready (this may take a minute)..."
kubectl wait --for=condition=ready pod -l app=replicatedgdb --timeout=120s || {
    echo -e "${YELLOW}⚠️  Pods are not ready yet. Check with 'kubectl get pods'${NC}"
}
echo ""

# Show status
echo "📊 Deployment Status:"
kubectl get statefulset replicatedgdb
echo ""
kubectl get pods -l app=replicatedgdb
echo ""

echo -e "${GREEN}✅ ReplicatedGDB is deployed!${NC}"
echo ""
echo "🌐 Access your instances:"
echo "   Instance 0: http://localhost:30000"
echo "   Instance 1: http://localhost:30001"
echo "   Instance 2: http://localhost:30002"
echo ""

if [ "$CLUSTER_TYPE" = "minikube" ]; then
    echo "💡 For Minikube, you may need to run 'minikube tunnel' in another terminal"
    echo "   Or use: minikube service replicatedgdb-0 --url"
    echo ""
fi

echo "📝 Useful commands:"
echo "   make status          - Check deployment status"
echo "   make logs            - View logs"
echo "   make test-all        - Test all instances"
echo "   make port-forward-all - Port forward all instances"
echo "   make delete          - Remove deployment"
echo ""
echo "For more information, see README.md and KUBERNETES.md"
