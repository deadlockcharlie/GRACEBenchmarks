# Optimized Deployment Flow with Pre-built Images

This deployment flow builds Docker images **once** locally and deploys them to all replicas, avoiding redundant builds on each node.

## Benefits

✅ **Build once, deploy everywhere** - Save time and bandwidth  
✅ **Faster deployments** - No compilation on each replica  
✅ **Consistent images** - Same image across all replicas  
✅ **Better caching** - Docker layer caching on your local machine  
✅ **Easier rollbacks** - Tagged images for version control  

## Complete Deployment Flow

### 1. Build Images Locally

```bash
# Build and push all images to Google Container Registry
cd gcp-deployment/scripts
./build-and-push-images.sh --database neo4j --tag v1.0

# Options:
# -d, --database TYPE    Database type (neo4j, mongodb, memgraph, janusgraph, arangodb)
# -t, --tag TAG         Image tag (default: latest)
# --skip-build          Skip building (only push)
# --skip-push           Skip pushing (only build)
```

**What this does:**
- Builds GRACE application image
- Builds network emulation (netem) image
- Builds database-specific images (if needed)
- Pushes all images to `gcr.io/YOUR_PROJECT/grace-*`
- Creates image manifest for deployment

### 2. Deploy Infrastructure (if not done)

```bash
./deploy-infrastructure.sh
```

### 3. Deploy Using Pre-built Images

```bash
# Deploy with pre-built images from GCR
./deploy-with-images.sh --database neo4j --replicas 3 --tag v1.0
```

**What this does:**
- Configures GCR authentication on all instances
- Pulls pre-built images (fast!)
- Deploys configurations only (small files)
- Generates docker-compose files
- Starts containers
- Verifies deployment

### 4. Run Benchmarks

```bash
./run-benchmark.sh --dataset yeast --duration 300
```

## Deployment Comparison

### Traditional Approach (Current)
```
Local Machine → [Source Code] → Replica 1 (build 5-10 min)
               → [Source Code] → Replica 2 (build 5-10 min)
               → [Source Code] → Replica 3 (build 5-10 min)
Total: 15-30 minutes just for builds!
```

### Optimized Approach (New)
```
Local Machine → [Build Once: 5-10 min] → GCR
GCR → [Image] → Replica 1 (pull: 1-2 min)
    → [Image] → Replica 2 (pull: 1-2 min)
    → [Image] → Replica 3 (pull: 1-2 min)
Total: 8-16 minutes (50% faster!)
```

## Directory Structure

```
gcp-deployment/
├── scripts/
│   ├── build-and-push-images.sh    # NEW: Build & push to GCR
│   ├── deploy-with-images.sh       # NEW: Deploy using images
│   ├── deploy-infrastructure.sh    # Existing: Terraform deployment
│   ├── deploy-application.sh       # Existing: Traditional deployment
│   └── run-benchmark.sh            # Existing: Run benchmarks
├── config/
│   ├── image-manifest.json         # Generated: Image registry info
│   ├── grace-app-image.txt         # Generated: Image references
│   └── ...
```

## Quick Commands

### Complete Fresh Deployment
```bash
# 1. Build images (run locally)
./scripts/build-and-push-images.sh -d neo4j -t v1.0

# 2. Deploy infrastructure
./scripts/deploy-infrastructure.sh

# 3. Deploy with images
./scripts/deploy-with-images.sh --database neo4j --tag v1.0

# 4. Run benchmark
./scripts/run-benchmark.sh
```

### Update Application Only
```bash
# Rebuild and push new version
./scripts/build-and-push-images.sh -d neo4j -t v1.1

# Redeploy (pulls new images)
./scripts/deploy-with-images.sh --database neo4j --tag v1.1
```

### Local Testing Before Push
```bash
# Build locally without pushing
./scripts/build-and-push-images.sh --skip-push

# Test locally
cd ../ReplicatedGDB
docker run -it gcr.io/YOUR_PROJECT/grace-app:latest
```

## Image Management

### List Images in GCR
```bash
gcloud container images list --repository=gcr.io/YOUR_PROJECT_ID
```

### View Image Tags
```bash
gcloud container images list-tags gcr.io/YOUR_PROJECT_ID/grace-app
```

### Delete Old Images
```bash
# Delete specific tag
gcloud container images delete gcr.io/YOUR_PROJECT_ID/grace-app:v1.0

# Delete all but latest
gcloud container images list-tags gcr.io/YOUR_PROJECT_ID/grace-app \
  --filter='-tags:*' --format='get(digest)' | \
  xargs -I {} gcloud container images delete gcr.io/YOUR_PROJECT_ID/grace-app@{} --quiet
```

## Cost Considerations

### Storage Costs
- **GCR Storage**: ~$0.026/GB/month
- **Typical GRACE image**: ~500MB
- **3 images (app, netem, db)**: ~1.5GB = ~$0.04/month
- **Worth it for**: Time saved (hours) vs. cost (pennies)

### Network Costs
- **Push from local**: Depends on your network (free if using GCP Cloud Shell)
- **Pull to instances**: Within GCP region = free (egress)
- **Cross-region pull**: ~$0.01/GB (minimal for small images)

## Troubleshooting

### Authentication Issues
```bash
# On local machine
gcloud auth login
gcloud auth configure-docker

# On GCP instances (automatically handled)
# If issues, SSH to instance and run:
gcloud auth configure-docker gcr.io
```

### Image Pull Failures
```bash
# Check if image exists
gcloud container images list --repository=gcr.io/YOUR_PROJECT_ID

# Test pull manually
ssh -F config/ssh-config grace-us-east1
sudo docker pull gcr.io/YOUR_PROJECT_ID/grace-app:latest
```

### Deployment Failures
```bash
# Check container logs
ssh -F config/ssh-config grace-us-east1
cd grace
sudo docker compose logs

# Check image manifest
cat config/image-manifest.json
```

## Advanced Usage

### Multi-Stage Deployments
```bash
# Stage 1: Development
./scripts/build-and-push-images.sh -t dev

# Stage 2: Testing
./scripts/build-and-push-images.sh -t test

# Stage 3: Production
./scripts/build-and-push-images.sh -t prod

# Deploy specific version
./scripts/deploy-with-images.sh --tag prod
```

### Rollback to Previous Version
```bash
# Deploy older version
./scripts/deploy-with-images.sh --tag v1.0

# Containers automatically pull and restart with old image
```

### CI/CD Integration
```bash
# In your CI/CD pipeline (GitHub Actions, Cloud Build, etc.)
- name: Build and Push
  run: |
    cd gcp-deployment/scripts
    ./build-and-push-images.sh -t ${{ github.sha }}

- name: Deploy
  run: |
    ./deploy-with-images.sh --tag ${{ github.sha }}
```

## Migration from Old Deployment

If you're currently using `deploy-application.sh`:

### Option 1: Switch Completely
```bash
# Stop using deploy-application.sh
# Start using build-and-push-images.sh + deploy-with-images.sh
```

### Option 2: Hybrid Approach
```bash
# Keep deploy-application.sh for quick tests
# Use new workflow for production deployments
```

### Option 3: Update Existing Script
```bash
# Modify deploy-application.sh to support --use-gcr flag
./deploy-application.sh --use-gcr --tag v1.0
# (This would require modifying the existing script)
```

## Best Practices

1. **Tag your images**: Use semantic versioning (v1.0, v1.1, v2.0)
2. **Keep latest tag**: Always tag with both version and 'latest'
3. **Clean old images**: Delete unused images monthly
4. **Test locally first**: Use --skip-push to test builds
5. **Document changes**: Use git tags matching image tags
6. **Automate CI/CD**: Integrate with your CI/CD pipeline

## Summary

The optimized deployment flow:
1. ✅ Saves 50%+ deployment time
2. ✅ Reduces network bandwidth usage
3. ✅ Provides consistent deployments
4. ✅ Enables easy rollbacks
5. ✅ Costs pennies per month
6. ✅ Integrates with CI/CD

**Recommended for**: Production deployments, multi-replica setups, frequent deployments
