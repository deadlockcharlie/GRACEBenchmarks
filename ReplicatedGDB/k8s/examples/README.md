# Kubernetes Configuration Examples

This directory contains example configurations for different deployment scenarios.

## Directory Structure

- `multi-database/` - Run different database backends on different instances
- `scaled/` - Configuration for running with more replicas (5+ instances)
- `production/` - Production-ready configuration with resource limits and monitoring

## Usage

Copy the desired configuration to the main `k8s/` directory:

```bash
# Example: Use multi-database setup
cp examples/multi-database/* k8s/
kubectl apply -f k8s/
```

Or apply directly:

```bash
kubectl apply -f examples/multi-database/
```
