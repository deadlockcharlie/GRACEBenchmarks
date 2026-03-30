# Multi-Data Center Deployment Guide

## Overview

This guide explains how to deploy ReplicatedGDB across **6 data centers (DCs)**, with each DC running a 3-node cluster for a total of 18 nodes globally distributed.

## Architecture

```
Global ReplicatedGDB System (6 Data Centers)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│  DC1 (us-east-1) │  │  DC2 (us-west-1) │  │ DC3 (eu-central) │
│  • Node 0, 1, 2  │  │  • Node 0, 1, 2  │  │  • Node 0, 1, 2  │
│  • Namespace: dc1│  │  • Namespace: dc2│  │  • Namespace: dc3│
└────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘
         │                     │                     │
         └─────────────────────┼─────────────────────┘
                               │
                    ┌──────────┴──────────┐
                    │  Global Y.js Hub    │
                    │  (CRDT Sync Layer)  │
                    └──────────┬──────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
┌────────┴─────────┐  ┌────────┴─────────┐  ┌────────┴─────────┐
│ DC4 (ap-south-1) │  │DC5 (ap-southeast)│  │ DC6 (sa-east-1)  │
│  • Node 0, 1, 2  │  │  • Node 0, 1, 2  │  │  • Node 0, 1, 2  │
│  • Namespace: dc4│  │  • Namespace: dc5│  │  • Namespace: dc6│
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

## Deployment Strategy

### Option 1: Single Kubernetes Cluster (Namespace per DC)

Use Kubernetes namespaces to logically separate each data center within a single cluster:

```bash
# Create namespaces for each DC
for dc in dc1 dc2 dc3 dc4 dc5 dc6; do
  kubectl create namespace $dc
done

# Deploy to each DC
for dc in dc1 dc2 dc3 dc4 dc5 dc6; do
  kubectl apply -f k8s/multi-dc/$dc/ -n $dc
done
```

**Pros:**
- Single control plane
- Simplified management
- Easy cross-DC communication within cluster

**Cons:**
- Not truly geo-distributed
- Single point of failure
- Network latency not representative of true multi-DC

### Option 2: Federated Kubernetes (Recommended for Production)

Deploy separate Kubernetes clusters in different regions and use Kubernetes Federation or multi-cluster management tools:

```bash
# Deploy to each cluster
for cluster_context in dc1-cluster dc2-cluster dc3-cluster dc4-cluster dc5-cluster dc6-cluster; do
  kubectl --context=$cluster_context apply -f k8s/multi-dc/base/
  kubectl --context=$cluster_context apply -f k8s/multi-dc/$cluster_context/
done
```

**Pros:**
- True geo-distribution
- Fault isolation between DCs
- Realistic network latency
- Scalable and resilient

**Cons:**
- More complex management
- Requires cross-cluster networking (VPN, service mesh)
- Higher operational overhead

### Option 3: Multi-Cluster on GKE (Recommended for GKE)

Use GKE's multi-cluster features with clusters in different regions:

```bash
# Create 6 GKE clusters in different regions
REGIONS=("us-east1" "us-west1" "europe-west1" "asia-south1" "asia-southeast1" "southamerica-east1")

for i in {1..6}; do
  gcloud container clusters create replicatedgdb-dc$i \
    --region=${REGIONS[$((i-1))]} \
    --num-nodes=1 \
    --machine-type=n1-standard-4 \
    --enable-ip-alias \
    --network=global-vpc \
    --subnetwork=subnet-${REGIONS[$((i-1))]}
done

# Configure multi-cluster ingress
# Deploy to each cluster
for i in {1..6}; do
  gcloud container clusters get-credentials replicatedgdb-dc$i --region=${REGIONS[$((i-1))]}
  kubectl apply -f k8s/multi-dc/dc$i/
done
```

## Configuration per Data Center

Each DC needs its own ConfigMap with DC-specific settings:

```yaml
# k8s/multi-dc/dc1/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: replicatedgdb-config
  labels:
    app: replicatedgdb
    datacenter: dc1
data:
  DATABASE: "MEMGRAPH"
  WS_URI: "ws://yjs-global-hub.default.svc.cluster.local:1234"
  DC_ID: "dc1"
  DC_REGION: "us-east-1"
  IS_PRELOAD_LEADER: "Yes"  # Only DC1 preloads
```

Repeat for dc2-dc6 with appropriate changes:
- `DC_ID`: "dc2", "dc3", etc.
- `DC_REGION`: region identifier
- `IS_PRELOAD_LEADER`: "No" for all except dc1

## Y.js WebSocket Hub Deployment

### Deploy Global Y.js WebSocket Server

```bash
# Create a dedicated namespace
kubectl create namespace yjs

# Deploy Y.js WebSocket server
kubectl apply -f k8s/multi-dc/yjs-hub/ -n yjs

# Expose via LoadBalancer for cross-cluster access
kubectl apply -f k8s/multi-dc/yjs-hub/service-lb.yaml -n yjs
```

Update the `WS_URI` in each DC's ConfigMap to point to this global hub.

## Port Allocation Strategy

### Per-DC Port Ranges
- DC1: NodePorts 30000-30002
- DC2: NodePorts 30010-30012
- DC3: NodePorts 30020-30022
- DC4: NodePorts 30030-30032
- DC5: NodePorts 30040-30042
- DC6: NodePorts 30050-30052

This ensures no port conflicts if using namespace-based separation.

## Monitoring and Observability

### Metrics Collection

Each DC exports metrics with DC labels:

```yaml
# Prometheus scrape config
- job_name: 'replicatedgdb-multi-dc'
  kubernetes_sd_configs:
  - role: pod
    namespaces:
      names:
      - dc1
      - dc2
      - dc3
      - dc4
      - dc5
      - dc6
  relabel_configs:
  - source_labels: [__meta_kubernetes_namespace]
    target_label: datacenter
```

### Key Metrics to Monitor

- **Cross-DC Latency**: Y.js sync latency between DCs
- **Per-DC Request Rate**: Requests handled by each DC
- **Data Divergence**: CRDT conflict resolution metrics
- **Network Connectivity**: WebSocket connection health
- **Database Performance**: Per-DC database query latency

## Deployment Commands

### Deploy All DCs (Namespace-based)

```bash
# Run the multi-DC deployment script
chmod +x scripts/deploy-multi-dc.sh
./scripts/deploy-multi-dc.sh

# Verify deployment
./scripts/verify-multi-dc.sh
```

### Deploy Specific DC

```bash
# Deploy only DC3
kubectl apply -f k8s/multi-dc/dc3/ -n dc3

# Verify
kubectl get pods -n dc3
```

### Scale a Specific DC

```bash
# Scale DC2 to 5 nodes
kubectl scale statefulset replicatedgdb --replicas=5 -n dc2
```

## Testing Cross-DC Synchronization

```bash
# Write to DC1
curl -X POST http://dc1-node-0:30000/api/addVertex \
  -H "Content-Type: application/json" \
  -d '{"id":"test-vertex","labels":["Test"],"properties":{"origin":"dc1"}}'

# Verify sync to DC6
sleep 2  # Allow sync time
curl http://dc6-node-0:30050/api/getGraph | jq '.vertices[] | select(.id=="test-vertex")'
```

## Consistency and Conflict Resolution

### CRDT-based Synchronization

Y.js provides eventual consistency through CRDTs:
- **Graph operations** are commutative
- **Concurrent updates** are automatically merged
- **No coordination** required between DCs

### Expected Behavior

- **Write to any DC**: Changes propagate to all DCs
- **Concurrent writes**: Resolved via CRDT rules (last-writer-wins for properties, set union for edges)
- **Network partition**: DCs continue operating independently, sync when reconnected
- **Sync latency**: Depends on network latency between DCs (typically <500ms globally)

## Disaster Recovery

### DC Failure Scenarios

1. **Single DC failure**: Other 5 DCs continue operating
2. **Hub failure**: DCs retain local state, sync resumes when hub recovers
3. **Network partition**: Split-brain handled by CRDT conflict resolution

### Backup Strategy

```bash
# Backup from each DC
for dc in dc1 dc2 dc3 dc4 dc5 dc6; do
  kubectl exec -n $dc replicatedgdb-0 -- /backup/script.sh > backup-$dc-$(date +%Y%m%d).tar.gz
done
```

## Performance Considerations

### Network Optimization

- Deploy Y.js hub in a central region or use regional hubs
- Use CDN or edge caching for read-heavy workloads
- Consider data locality for database placement

### Database Strategy

**Option A: Shared Global Database**
- Single database cluster replicated across regions
- Higher consistency, higher latency

**Option B: Per-DC Database**
- Each DC has its own database
- Lower latency, eventual consistency via Y.js

**Option C: Hybrid**
- DC1-DC3 share one database
- DC4-DC6 share another
- Balance between consistency and latency

## Cost Optimization on GKE

```bash
# Use preemptible nodes for non-critical DCs
gcloud container node-pools create preemptible-pool \
  --cluster=replicatedgdb-dc4 \
  --region=asia-south1 \
  --preemptible \
  --num-nodes=3

# Use smaller machines for lower-traffic DCs
# Larger machines for high-traffic DCs (DC1, DC2)
```

## Next Steps

1. **Deploy single DC** and verify functionality
2. **Deploy Y.js hub** globally accessible
3. **Add second DC** and test cross-DC sync
4. **Gradually scale** to all 6 DCs
5. **Monitor and tune** based on actual traffic patterns
6. **Implement geo-routing** to direct users to nearest DC
7. **Set up alerting** for cross-DC sync failures

## Troubleshooting

### Sync Issues

```bash
# Check Y.js hub connectivity from each DC
for dc in dc1 dc2 dc3 dc4 dc5 dc6; do
  kubectl exec -n $dc replicatedgdb-0 -- curl -I ws://yjs-hub:1234
done
```

### High Latency

```bash
# Measure inter-DC latency
kubectl run -n dc1 ping --image=busybox --restart=Never -- \
  ping replicatedgdb-0.dc6.svc.cluster.local
```

### Data Inconsistency

```bash
# Compare graph state across DCs
for dc in dc1 dc2 dc3 dc4 dc5 dc6; do
  echo "=== $dc ==="
  curl http://$dc-endpoint:30000/api/getGraph | jq '.vertices | length'
done
```

## See Also

- [GKE Multi-Cluster Documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/multi-cluster)
- [Y.js WebSocket Provider](https://github.com/yjs/y-websocket)
- [Kubernetes Federation](https://github.com/kubernetes-sigs/kubefed)
- [CRDT Conflict Resolution](https://crdt.tech/)
