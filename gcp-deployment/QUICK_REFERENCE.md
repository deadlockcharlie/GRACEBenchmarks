# GCP Deployment - Quick Reference

## One-Command Deployment

```bash
cd gcp-deployment
./quickstart.sh
```

This interactive script will:
1. Check prerequisites (gcloud, terraform, jq)
2. Verify GCP authentication
3. Configure SSH keys
4. Let you choose deployment type (Free/Test/Production)
5. Deploy infrastructure
6. Deploy application
7. Provide next steps

---

## Prerequisites

```bash
# Install gcloud CLI (macOS)
brew install google-cloud-sdk

# Install Terraform
brew install terraform

# Install jq
brew install jq

# Authenticate with GCP
gcloud auth login
gcloud auth application-default login

# Set project
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable compute.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
```

---

## Manual Deployment Steps

### 1. Configure

```bash
cd gcp-deployment/terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

**Required changes:**
- `project_id`: Your GCP project ID
- `ssh_public_key`: Your SSH public key (format: "username:ssh-rsa AAAA...")
- `machine_type`: e2-micro (free) or n2-standard-8 (benchmarks)
- `allowed_ssh_ips`: Your IP address for security

### 2. Deploy Infrastructure

```bash
cd gcp-deployment/scripts
./deploy-infrastructure.sh
```

### 3. Deploy Application

```bash
./deploy-application.sh --database neo4j --replicas 3
```

### 4. Run Benchmarks

```bash
./run-benchmark.sh --dataset yeast --duration 300 --threads 64
```

### 5. Collect Results

```bash
./collect-results.sh
```

### 6. Teardown (IMPORTANT!)

```bash
./teardown.sh
```

---

## Cost Tiers

### Free Tier (e2-micro)
- **Cost:** FREE (1 e2-micro free per month)
- **Resources:** 0.25-2 vCPU (shared), 1GB RAM
- **Use Case:** Exploring deployment
- **Config:** `machine_type = "e2-micro"`

### Quick Test (n2-standard-4)
- **Cost:** ~$0.19/hr per instance = ~$0.57/hr for 3 regions
- **Resources:** 4 vCPU, 16GB RAM
- **Use Case:** Quick testing
- **Config:** `machine_type = "n2-standard-4"`

### Standard Benchmark (n2-standard-8)
- **Cost:** ~$0.39/hr per instance = ~$1.17/hr for 3 regions
- **Resources:** 8 vCPU, 32GB RAM
- **Use Case:** Production benchmarks
- **Config:** `machine_type = "n2-standard-8"`

---

## Common Commands

### Check Resources
```bash
cd gcp-deployment/scripts
./check-resources.sh
```

### SSH to Instances
```bash
# Using generated config
ssh -F gcp-deployment/config/ssh-config grace-us-east1

# Direct
ssh -i ~/.ssh/google_compute_engine $(whoami)@<ip-address>
```

### View Instance Logs
```bash
ssh $(whoami)@<ip> "docker logs -f app1"
```

### Restart Application
```bash
ssh $(whoami)@<ip> "cd grace/ReplicatedGDB && docker-compose restart"
```

---

## File Locations

- **Infrastructure:** `gcp-deployment/terraform/`
- **Deployment Scripts:** `gcp-deployment/scripts/`
- **Configuration:** `gcp-deployment/config/`
- **Results:** `Results/gcp_*/`

---

## Database Options

```bash
# Neo4j (default)
./deploy-application.sh --database neo4j

# MongoDB
./deploy-application.sh --database mongodb

# MemGraph
./deploy-application.sh --database memgraph

# ArangoDB
./deploy-application.sh --database arangodb
```

---

## Regions

- **us-east1** (South Carolina)
- **us-west1** (Oregon)
- **europe-west1** (Belgium)

---

## Troubleshooting

### API Not Enabled
```bash
gcloud services enable compute.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
```

### Permission Denied
```bash
# Re-authenticate
gcloud auth login
gcloud auth application-default login
```

### SSH Connection Failed
```bash
# Check SSH key
ls -la ~/.ssh/google_compute_engine

# Generate if missing
ssh-keygen -t rsa -b 4096 -f ~/.ssh/google_compute_engine

# Check firewall rules
gcloud compute firewall-rules list --filter="name~grace-"
```

### Instance Not Starting
```bash
# Check startup script logs
gcloud compute instances get-serial-port-output grace-us-east1 --zone=us-east1-b

# SSH and check
ssh $(whoami)@<ip>
sudo journalctl -u google-startup-scripts.service
```

---

## Cost Management

### Set Budget Alert
```bash
# Via Console
https://console.cloud.google.com/billing/budgets

# Or create alert programmatically
gcloud billing budgets create \
  --billing-account=YOUR_BILLING_ACCOUNT_ID \
  --display-name="GRACE Budget" \
  --budget-amount=100USD
```

### Monitor Costs
```bash
# View current month costs
https://console.cloud.google.com/billing

# Check running instances
./check-resources.sh
```

### Stop Charges
```bash
# Always run teardown when done!
./teardown.sh

# Verify everything is deleted
./check-resources.sh
```

---

## Performance Tips

1. **Use n2-standard-8 or larger** for accurate benchmarks
2. **Increase disk size** to 100GB for large datasets
3. **Use SSD persistent disks** for better I/O:
   ```hcl
   # In terraform/modules/compute/main.tf
   boot_disk {
     initialize_params {
       type = "pd-ssd"  # Instead of pd-standard
     }
   }
   ```
4. **Enable IP forwarding** for better network performance (already configured)

---

## Support

- **Documentation:** [gcp-deployment/README.md](README.md)
- **GCP Setup:** [gcp-deployment/GCP_SETUP.md](GCP_SETUP.md)
- **Issues:** Check terraform output for detailed error messages
