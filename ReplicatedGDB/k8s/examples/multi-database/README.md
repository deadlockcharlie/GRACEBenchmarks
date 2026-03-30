# Multi-Database Configuration

This example shows how to configure different instances to use different database backends.
This is useful for:
- Benchmarking different databases
- A/B testing
- Migration scenarios

## Setup

Each instance uses a dedicated ConfigMap with its own database configuration:

- Instance 0: Memgraph
- Instance 1: ArangoDB  
- Instance 2: MongoDB

## Deployment

```bash
# Deploy with per-instance configuration
kubectl apply -f k8s/examples/multi-database/

# Check which database each instance is using
kubectl logs replicatedgdb-0 | grep "Database specified"
kubectl logs replicatedgdb-1 | grep "Database specified"
kubectl logs replicatedgdb-2 | grep "Database specified"
```

## Prerequisites

You need to have the respective database services running and accessible:

```bash
# Example: Deploy database services (adjust as needed)
# Memgraph
kubectl run memgraph --image=memgraph/memgraph --port=7687

# ArangoDB
kubectl run arangodb --image=arangodb:latest --port=8529

# MongoDB
kubectl run mongodb --image=mongo:latest --port=27017
```

## Customization

Edit the individual ConfigMaps in `configmap-per-instance.yaml` to:
- Change database connection strings
- Set different ports
- Configure per-instance behavior
