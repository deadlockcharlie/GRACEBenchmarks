# ReplicatedGDB - Kubernetes Deployment Guide

This guide explains how to containerize and deploy ReplicatedGDB locally using Kubernetes.

## Prerequisites

- Docker installed
- Kubernetes cluster running locally (e.g., minikube, Docker Desktop with Kubernetes, or kind)
- kubectl configured to communicate with your cluster

## Quick Start

## Architecture Overview

The deployment creates a multi-instance setup where each server runs on its own pod but shares synchronized state via Y.js:

```
┌─────────────────────────────────────────────────────────────────┐
│                        Kubernetes Cluster                       │
│                                                                 │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐     │
│  │ replicatedgdb-0│  │ replicatedgdb-1│  │ replicatedgdb-2│     │
│  │                │  │                │  │                │     │
│  │  Port 3000     │  │  Port 3000     │  │  Port 3000     │     │
│  └───────┬────────┘  └───────┬────────┘  └───────┬────────┘     │
│          │                   │                   │              │
│  ┌───────┴────────┬──────────┴────────┬──────────┴────────┐     │
│  │                │                   │                    │    │
│  │  Service       │    Service        │    Service         │    │
│  │  (NodePort     │    (NodePort      │    (NodePort       │    │
│  │   30000)       │     30001)        │     30002)         │    │
│  └────────────────┴───────────────────┴────────────────────┘    │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │         Headless Service (for pod DNS)                   │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                            │
                    Y.js WebSocket Server
                            │
                    (External or in-cluster)
```

Each instance:
- Has a unique identity (replicatedgdb-0, replicatedgdb-1, etc.)
- Exposes its own NodePort (30000, 30001, 30002)
- Connects to the same Y.js WebSocket server for CRDT synchronization
- Can connect to its own database or share a common one

### 1. Build the Docker Image

```bash
docker build -t replicatedgdb:latest .

# Or use the Makefile
make build
```

### 2. Load Image into Your Local Kubernetes Cluster

#### For Minikube:
```bash
# Use minikube's Docker daemon
eval $(minikube docker-env)
docker build -t replicatedgdb:latest .
```

#### For kind:
```bash
kind load docker-image replicatedgdb:latest
```

#### For Docker Desktop:
The image is already available to Kubernetes.

### 3. Configure the Application

Edit `k8s/configmap.yaml` to set your database and WebSocket configuration:

```yaml
data:
  DATABASE: "MEMGRAPH"  # Options: NEO4J, MEMGRAPH, JANUSGRAPH, ARANGODB, MONGODB
  WS_URI: "ws://your-websocket-server:1234"
  IS_PRELOAD_LEADER: "No"
```

### 4. Deploy to Kubernetes

```bash
# Apply all manifests
kubectl apply -f k8s/

# Or use the Makefile
make deploy
```

This will create:
- A StatefulSet with 3 replicas (each with a unique identity)
- A headless service for internal pod-to-pod communication
- Individual NodePort services for each instance (ports 30000, 30001, 30002)
- A load-balanced service for general access

### 5. Verify Deployment

```bash
# Check StatefulSet status
kubectl get statefulset replicatedgdb

# Check pod status
kubectl get pods -l app=replicatedgdb

# Check logs
kubectl logs -l app=replicatedgdb -f

# Check all services
kubectl get svc | grep replicatedgdb

# Use the test script to verify all instances
chmod +x scripts/test-instances.sh
./scripts/test-instances.sh
```

### 6. Access the Application

The deployment creates multiple server instances, each accessible on a different port:

```bash
# Check all services
kubectl get svc

# Access individual instances on different ports:
# Instance 0: localhost:30000
# Instance 1: localhost:30001
# Instance 2: localhost:30002

# For minikube, use:
minikube service replicatedgdb-0 --url  # First instance
minikube service replicatedgdb-1 --url  # Second instance
minikube service replicatedgdb-2 --url  # Third instance

# Or use load-balanced access to any instance:
minikube service replicatedgdb --url

# Port forwarding for specific instances:
kubectl port-forward replicatedgdb-0 3000:3000  # First instance to localhost:3000
kubectl port-forward replicatedgdb-1 3001:3000  # Second instance to localhost:3001
kubectl port-forward replicatedgdb-2 3002:3000  # Third instance to localhost:3002
```

Access the instances at:
- `http://localhost:30000` (or via port-forward at `http://localhost:3000`)
- `http://localhost:30001` (or via port-forward at `http://localhost:3001`)
- `http://localhost:30002` (or via port-forward at `http://localhost:3002`)

**Tip**: Use the helper script to port-forward all instances at once:
```bash
chmod +x scripts/port-forward-all.sh
./scripts/port-forward-all.sh
```

## Configuration Options

### Environment Variables

Configure via `k8s/configmap.yaml`:

- **DATABASE**: Database type (NEO4J, MEMGRAPH, JANUSGRAPH, ARANGODB, MONGODB)
- **WS_URI**: WebSocket server URI for Y.js synchronization
- **IS_PRELOAD_LEADER**: Set to "Yes" for the pod that handles data preloading
- **PORT**: Application port (default: 3000)

### Data Preloading

If you need to preload data from JSON files:

1. Uncomment the volume sections in `k8s/deployment.yaml`
2. Update the `hostPath` to point to your data directory
3. Set `IS_PRELOAD_LEADER: "Yes"` in the ConfigMap
4. Place your `vertices.json` and `edges.json` files in the specified directory

### Scaling

The application uses a StatefulSet for stable network identities. Each pod gets:
- A unique hostname: `replicatedgdb-0`, `replicatedgdb-1`, `replicatedgdb-2`, etc.
- A dedicated service with its own NodePort
- Stable storage (if PersistentVolumeClaims are configured)

```bash
# Scale the StatefulSet (adds/removes instances)
kubectl scale statefulset replicatedgdb --replicas=5

# After scaling up, create additional services for new instances

# Check specific instance
kubectl describe pod replicatedgdb-0
```

### View Logs
```bash
# All instances
kubectl logs -l app=replicatedgdb --tail=100 -f

# Specific instance
kubectl logs replicatedgdb-0 -f
kubectl logs replicatedgdb-1 -f
kubectl logs replicatedgdb-2 -f
```

### Exec into Pod
```bash
# Exec into specific instance
kubectl exec -it replicatedgdb-0 -- sh
kubectl exec -it replicatedgdb-1
```

### View Logs
```bash
kubectl logs -l app=replicatedgdb --tail=100 -f
```

### Test Individual Instances
```bash
# Test readiness of each instance
curl http://localhost:30000/ready  # Instance 0
curl http://localhost:30001/ready  # Instance 1
curl http://localhost:30002/ready  # Instance 2
```

### Exec into Pod
```bash
kubectl exec -it deployment/replicatedgdb -- sh
```

### Delete and Redeploy
```bash
kubectl delete -f k8s/
kubectl apply -f k8s/
```

## Multi-Data Center Deployment

This 3-node cluster represents a **single data center (DC)**. For production deployments across **6 geographically distributed data centers** (18 total nodes), see [MULTI-DC.md](MULTI-DC.md) for:

- Multi-DC architecture and deployment strategies  
- Namespace-based DC separation
- GKE multi-cluster setup across regions
- Cross-DC synchronization testing and verification
- Performance benchmarking across DCs
- Disaster recovery and consistency guarantees

### Quick Multi-DC Setup

```bash
# Deploy across 6 DCs using namespaces
chmod +x scripts/deploy-multi-dc.sh
./scripts/deploy-multi-dc.sh

# Verify all DCs
./scripts/verify-multi-dc.sh

# Test cross-DC sync
./scripts/test-cross-dc.sh
```

Each DC will have:
- 3 nodes in its own namespace (dc1-dc6)
- Unique NodePort range per DC
- Connection to global Y.js hub for cross-DC CRDTsynchronization
- DC-specific configuration (region, preload leader, etc.)

## API Endpoints

- `GET /ready` - Readiness check
- `GET /api/getGraph` - Get the graph
- `POST /api/addVertex` - Add a vertex
- `POST /api/deleteVertex` - Delete a vertex
- `POST /api/addEdge` - Add an edge
- `POST /api/deleteEdge` - Delete an edge
- `POST /api/setVertexProperty` - Set vertex property
- `POST /api/setEdgeProperty` - Set edge property
- `POST /api/removeVertexProperty` - Remove vertex property
- `POST /api/removeEdgeProperty` - Remove edge property
- `POST /reset` - Reset the graph

## Next Steps for GKE

When ready to deploy to Google Kubernetes Engine (GKE):

1. Push the image to Google Container Registry (GCR) or Artifact Registry:
   ```bash
   docker tag replicatedgdb:latest gcr.io/[PROJECT_ID]/replicatedgdb:latest
   docker push gcr.io/[PROJECT_ID]/replicatedgdb:latest
   ```

2. Update `k8s/deployment.yaml`:
   - Change `imagePullPolicy` from `Never` to `IfNotPresent`
   - Update image to use your GCR/Artifact Registry path

3. Create GKE cluster and deploy
4. Consider using Cloud SQL, Cloud Memorystore, or managed database services
5. Set up proper secrets management for sensitive configuration
6. Configure Ingress for external access
7. Set up monitoring and logging with Cloud Monitoring
