# ReplicatedGDB - Quick Reference Guide

## What is ReplicatedGDB?

A distributed graph database system with:
- **Multi-backend support**: Neo4j, Memgraph, JanusGraph, ArangoDB, MongoDB
- **CRDT-based replication**: Conflict-free synchronization via Y.js
- **Multi-DC deployment**: Scale across 6 geographically distributed data centers
- **Kubernetes-native**: StatefulSet-based deployment with per-instance services

## Quick Commands

### Single DC Deployment (3 nodes)

```bash
# Build and deploy
make build
make deploy

# Check status
make status

# View logs
make logs

# Test
make test-all

# Delete
make delete
```

### Multi-DC Deployment (6 DCs × 3 nodes = 18 nodes)

```bash
# Build and deploy all DCs
make deploy-multi-dc

# Verify deployment
make verify-multi-dc

# Test cross-DC sync
make test-cross-dc

# Benchmark
make benchmark-multi-dc

# Check status
make status-multi-dc

# Delete all DCs
make delete-multi-dc
```

## Architecture

### Single DC (3 nodes)
```
┌─────────────────────────────────────┐
│     Data Center (Namespace: dc1)    │
│                                     │
│  Node 0    Node 1    Node 2         │
│  :30000    :30001    :30002         │
│     │         │         │           │
│     └─────────┴─────────┘           │
│              │                      │
│      Y.js WebSocket Hub             │
└─────────────────────────────────────┘
```

### Multi-DC (18 nodes across 6 DCs)
```
DC1 (us-east-1)      DC2 (us-west-1)      DC3 (eu-central-1)
  3 nodes              3 nodes              3 nodes
     │                    │                    │
     └────────────────────┼────────────────────┘
                          │
              ┌───────────┴───────────┐
              │   Global Y.js Hub     │
              └───────────┬───────────┘
                          │
     ┌────────────────────┼────────────────────┐
     │                    │                    │
DC4 (asia-south-1)   DC5 (asia-se-1)     DC6 (sa-east-1)
  3 nodes              3 nodes              3 nodes
```

## Port Allocation

### Single DC
- Node 0: 30000
- Node 1: 30001
- Node 2: 30002

### Multi-DC
| DC  | Region          | NodePorts     |
|-----|-----------------|---------------|
| DC1 | us-east-1       | 30000-30002   |
| DC2 | us-west-1       | 30010-30012   |
| DC3 | eu-central-1    | 30020-30022   |
| DC4 | asia-south-1    | 30030-30032   |
| DC5 | asia-southeast-1| 30040-30042   |
| DC6 | sa-east-1       | 30050-30052   |

## Configuration

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DATABASE` | Database type | MEMGRAPH, NEO4J, ARANGODB, MONGODB, JANUSGRAPH |
| `WS_URI` | Y.js WebSocket server | ws://yjs-hub:1234 |
| `DC_ID` | Data center identifier | dc1, dc2, ... dc6 |
| `DC_REGION` | Geographic region | us-east-1, eu-central-1 |
| `IS_PRELOAD_LEADER` | Preload data? | Yes (only one DC), No |
| `PORT` | Server port | 3000 (default) |

### Files

| File | Purpose |
|------|---------|
| `k8s/configmap.yaml` | Single DC configuration |
| `k8s/deployment.yaml` | StatefulSet for single DC |
| `k8s/service.yaml` | Services for single DC |
| `k8s/multi-dc/templates/` | Templates for multi-DC |
| `scripts/deploy-multi-dc.sh` | Multi-DC deployment script |
| `scripts/verify-multi-dc.sh` | Verification script |
| `scripts/test-cross-dc.sh` | Cross-DC sync test |

## API Reference

### Health
- `GET /ready` - Readiness probe

### Graph Operations
- `GET /api/getGraph` - Get entire graph
- `GET /getVertex?id={id}` - Get specific vertex
- `POST /api/addVertex` - Add vertex
- `POST /api/deleteVertex` - Delete vertex
- `POST /api/addEdge` - Add edge
- `POST /api/deleteEdge` - Delete edge
- `POST /reset` - Clear graph

### Properties
- `POST /api/setVertexProperty` - Set vertex property
- `POST /api/setEdgeProperty` - Set edge property
- `POST /api/removeVertexProperty` - Remove vertex property
- `POST /api/removeEdgeProperty` - Remove edge property

## Common Tasks

### Access an Instance

```bash
# Single DC
kubectl port-forward replicatedgdb-0 3000:3000

# Multi-DC - specific DC
kubectl port-forward -n dc3 replicatedgdb-0 3000:3000

# Access
curl http://localhost:3000/ready
```

### View Logs

```bash
# Single DC - specific node
kubectl logs replicatedgdb-0 -f

# Multi-DC - specific DC and node
kubectl logs -n dc2 replicatedgdb-1 -f

#All nodes in a DC
kubectl logs -n dc1 -l app=replicatedgdb -f
```

### Add Test Data

```bash
# Add vertex
curl -X POST http://localhost:3000/api/addVertex \
  -H "Content-Type: application/json" \
  -d '{"id":"v1","labels":["Person"],"properties":{"name":"Alice"}}'

# Add edge
curl -X POST http://localhost:3000/api/addEdge \
  -H "Content-Type: application/json" \
  -d '{"id":"e1","label":"KNOWS","from":"v1","to":"v2","properties":{"since":2020}}'
```

### Scale Deployment

```bash
# Single DC
kubectl scale statefulset replicatedgdb --replicas=5

# Multi-DC - specific DC
kubectl scale statefulset replicatedgdb --replicas=5 -n dc3
```

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -l app=replicatedgdb

# View events
kubectl describe pod replicatedgdb-0

# Check logs
kubectl logs replicatedgdb-0
```

### Cross-DC Sync Not Working

```bash
# Check Y.js hub
kubectl get pods -n yjs
kubectl logs -n yjs -l app=yjs-hub

# Test connectivity
kubectl exec -n dc2 replicatedgdb-0 -- \
  nslookup yjs-hub.yjs.svc.cluster.local

# Verify WebSocket connection
kubectl logs -n dc1 replicatedgdb-0 | grep "WebSocket\|Y.js"
```

### High Latency

```bash
# Check resource usage
kubectl top pods -l app=replicatedgdb

# Increase resources
# Edit k8s/deployment.yaml:
resources:
  limits:
    memory: "8Gi"
    cpu: "4000m"
```

### Port Already in Use

```bash
# Find process using port
lsof -i :30000

# Kill port-forward
pkill -f "kubectl port-forward"
```

## Performance Tips

1. **Database Selection**
   - Memgraph: Fastest for graph queries
   - ArangoDB: Best for mixed workloads
   - MongoDB: Good for document-heavy graphs

2. **Resource Allocation**
   - Minimum: 512Mi RAM, 250m CPU
   - Recommended: 2-4Gi RAM, 1-2 CPU cores
   - High performance: 8Gi+ RAM, 4+ CPU cores

3. **Network Optimization**
   - Deploy Y.js hub in central region
   - Use regional databases for lower latency
   - Consider edge caching for read-heavy workloads

4. **Scaling Strategy**
   - Start with 3 nodes per DC
   - Scale to 5-7 nodes for high traffic
   - Add DCs for geographic distribution

## Documentation

- **README.md** - Project overview and quick start
- **KUBERNETES.md** - Single DC Kubernetes deployment
- **MULTI-DC.md** - Multi-DC deployment guide
- **QUICK-REFERENCE.md** - This file

## Support

For issues, questions, or contributions:
1. Check logs: `kubectl logs <pod-name>`
2. Review events: `kubectl describe pod <pod-name>`
3. Verify configuration: `kubectl get configmap replicatedgdb-config -o yaml`
4. Test connectivity: `curl http://localhost:30000/ready`

## Next Steps

1. ✅ Deploy single DC locally
2. ✅ Test basic operations
3. ✅ Deploy multi-DC
4. ✅ Verify cross-DC sync
5. 🔄 Deploy to GKE with global clusters
6. 🔄 Set up monitoring and alerting
7. 🔄 Configure geo-routing
8. 🔄 Implement backup and disaster recovery
