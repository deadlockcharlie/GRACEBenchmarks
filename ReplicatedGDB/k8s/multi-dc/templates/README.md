# Multi-DC Configuration Template

This directory contains templates and examples for multi-data center deployments.

## Files

- `configmap-template.yaml` - Template ConfigMap for a single DC
- `deployment-dc-template.yaml` - Template StatefulSet for a single DC  
- `service-dc-template.yaml` - Template Services for a single DC

## Usage

### Manual Deployment

1. Copy template files for each DC:
```bash
for dc in dc1 dc2 dc3 dc4 dc5 dc6; do
  mkdir -p k8s/multi-dc/$dc
  cp k8s/multi-dc/templates/*.yaml k8s/multi-dc/$dc/
  # Edit files to replace placeholders
done
```

2. Replace placeholders in each file:
- `{{DC_ID}}` → dc1, dc2, etc.
- `{{DC_REGION}}` → us-east-1, eu-central-1, etc.
- `{{BASE_NODE_PORT}}` → 30000, 30010, 30020, etc.
- `{{IS_PRELOAD_LEADER}}` → "Yes" for dc1, "No" for others

3. Deploy:
```bash
for dc in dc1 dc2 dc3 dc4 dc5 dc6; do
  kubectl create namespace $dc
  kubectl apply -f k8s/multi-dc/$dc/ -n $dc
done
```

### Automated Deployment

Use the deployment script:
```bash
./scripts/deploy-multi-dc.sh
```

This automatically:
- Creates namespaces
- Generates configurations from templates
- Deploys Y.js hub
- Deploys all DCs
- Verifies deployment

## Customization

### Change Database per DC

Edit ConfigMap to use different databases:
```yaml
# DC1 - Memgraph
DATABASE: "MEMGRAPH"

# DC2 - ArangoDB  
DATABASE: "ARANGODB"

# DC3 - MongoDB
DATABASE: "MONGODB"
```

### Adjust Resources

Edit deployment template:
```yaml
resources:
  requests:
    memory: "1Gi"      # Increase for larger datasets
    cpu: "500m"
  limits:
    memory: "8Gi"
    cpu: "4000m"
```

### Change Replica Count

Edit deployment template:
```yaml
spec:
  replicas: 5  # Scale to 5 nodes per DC
```

Then update service templates to create services for nodes 0-4.
