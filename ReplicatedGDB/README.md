# ReplicatedGDB

A replicated graph database system built with Node.js, supporting multiple backend databases and Yjs-based synchronization.

## Features

- **Multiple Database Backends**: Support for Neo4j, Memgraph, JanusGraph, ArangoDB, and MongoDB
- **Y.js Synchronization**: Real-time CRDT-based synchronization across instances
- **REST API**: Full graph operations via HTTP endpoints
- **Multi-Instance Deployment**: Run multiple server instances on different ports
- **Kubernetes Ready**: StatefulSet deployment with individual instance access
- **Multi-DC Architecture**: Supports deployment across 6 geographically distributed data centers (18 total nodes)

## Supported Databases

- **NEO4J** / **MEMGRAPH**: Property graph databases with Cypher support


## Quick Start (Local Development)

```bash
# Install dependencies
npm install

# Build the application
npm run build

# Set environment variables
export DATABASE=MEMGRAPH
export WS_URI=ws://localhost:1234
export PORT=3000

# Run the application
npm start
```

## Kubernetes Deployment

For local Kubernetes deployment (minikube, kind, Docker Desktop):

### Automated Quick Start

```bash
# Make the script executable
chmod +x quickstart.sh

# Run the automated deployment
./quickstart.sh
```

This script will:
1. Check prerequisites (Docker, kubectl, cluster)
2. Build the Docker image
3. Load it into your cluster (if needed)
4. Deploy all Kubernetes resources
5. Wait for pods to be ready
6. Show access URLs

### Manual Deployment

```bash
# Build Docker image
make build

# Deploy to Kubernetes (creates 3 instances)
make deploy

# Check status
make status

# Test all instances
make test-all

# Port forward all instances for local access
make port-forward-all
```

Each instance is accessible on a separate port:
- Instance 0: `http://localhost:30000`
- Instance 1: `http://localhost:30001`
- Instance 2: `http://localhost:30002`

See [KUBERNETES.md](KUBERNETES.md) for detailed Kubernetes deployment instructions, including GKE preparation.

## API Endpoints

### Health & Monitoring
- `GET /ready` - Readiness probe

### Graph Operations
- `GET /api/getGraph` - Retrieve the entire graph
- `POST /api/addVertex` - Add a vertex
- `POST /api/deleteVertex` - Delete a vertex
- `POST /api/addEdge` - Add an edge
- `POST /api/deleteEdge` - Delete an edge
- `POST /reset` - Clear the graph

### Property Operations
- `POST /api/setVertexProperty` - Set a property on a vertex
- `POST /api/setEdgeProperty` - Set a property on an edge
- `POST /api/removeVertexProperty` - Remove a property from a vertex
- `POST /api/removeEdgeProperty` - Remove a property from an edge

## Architecture

### Components

- **Express Server**: HTTP API server
- **Y.js CRDT**: Conflict-free replicated data type for synchronization
- **Database Drivers**: Pluggable drivers for different graph databases
- **Prometheus Metrics**: Built-in metrics collection

### Multi-Instance Setup

The application uses Kubernetes StatefulSets to run multiple instances, each with:
- Unique pod identity (`replicatedgdb-0`, `replicatedgdb-1`, etc.)
- Dedicated NodePort service for direct access
- Shared Y.js WebSocket for synchronization
- Individual database connections

## Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `DATABASE` | Database type (NEO4J, MEMGRAPH, JANUSGRAPH, ARANGODB, MONGODB) | - | Yes |
| `WS_URI` | WebSocket URI for Y.js synchronization | - | Yes |
| `PORT` | Server port | 3000 | No |
| `IS_PRELOAD_LEADER` | Whether this instance handles data preload (Yes/No) | No | No |

## Data Preloading

The application can preload graph data from JSON files:

- `/var/lib/grace/import/vertices.json` - Vertex data
- `/var/lib/grace/import/edges.json` - Edge data

Set `IS_PRELOAD_LEADER=Yes` for one instance to handle the initial data load.

## Development

```bash
# Install dependencies
npm install

# Run in development mode (with TypeScript compilation)
npm start

# Build only
npm run build

# Lint code (if configured)
npm test
```

## Makefile Commands

| Command | Description |
|---------|-------------|
| `make build` | Build Docker image |
| `make deploy` | Deploy to Kubernetes |
| `make status` | Check deployment status |
| `make logs` | View logs from all instances |
| `make logs-instance INSTANCE=0` | View logs from specific instance |
| `make shell INSTANCE=0` | Exec into a specific pod |
| `make port-forward INSTANCE=0` | Port forward a specific instance |
| `make port-forward-all` | Port forward all instances |
| `make test-all` | Test all instance endpoints |
| `make scale REPLICAS=5` | Scale to N instances |
| `make delete` | Delete Kubernetes resources |
| `make help` | Show all available commands |

## Files

- `Dockerfile` - Multi-stage Docker build configuration
- `k8s/` - Kubernetes manifests
  - `deployment.yaml` - StatefulSet configuration
  - `service.yaml` - Services for each instance and load balancing
  - `configmap.yaml` - Environment configuration
- `scripts/` - Helper scripts
  - `test-instances.sh` - Test all running instances
  - `port-forward-all.sh` - Port forward all instances at once
- `KUBERNETES.md` - Detailed Kubernetes deployment guide
- `MULTI-DC.md` - Multi-data center deployment guide for 6 DCs

## Multi-Data Center Deployment

ReplicatedGDB supports deployment across **6 geographically distributed data centers**, with each DC running a 3-node cluster (18 total nodes).

### Quick Multi-DC Setup

```bash
# Deploy across 6 DCs using namespaces
chmod +x scripts/deploy-multi-dc.sh
./scripts/deploy-multi-dc.sh

# Verify deployment
./scripts/verify-multi-dc.sh

# Test cross-DC synchronization
./scripts/test-cross-dc.sh

# Benchmark all DCs
./scripts/benchmark-multi-dc.sh
```

### Architecture

- **Per-DC**: 3 nodes (replicatedgdb-0, replicatedgdb-1, replicatedgdb-2)
- **Total**: 18 nodes across 6 DCs
- **Synchronization**: Global Y.js WebSocket hub for CRDT-based conflict-free replication
- **Consistency**: Eventual consistency with automatic conflict resolution
- **Isolation**: Each DC in separate Kubernetes namespace (dc1-dc6)

### Data Center Layout

| DC  | Region          | Namespace | NodePorts     |
|-----|-----------------|-----------|---------------|
| DC1 | us-east-1       | dc1       | 30000-30002   |
| DC2 | us-west-1       | dc2       | 30010-30012   |
| DC3 | eu-central-1    | dc3       | 30020-30022   |
| DC4 | asia-south-1    | dc4       | 30030-30032   |
| DC5 | asia-southeast-1| dc5       | 30040-30042   |
| DC6 | sa-east-1       | dc6       | 30050-30052   |

See [MULTI-DC.md](MULTI-DC.md) for detailed multi-DC deployment guide, including GKE multi-cluster setup, monitoring, and disaster recovery.

## License

ISC
