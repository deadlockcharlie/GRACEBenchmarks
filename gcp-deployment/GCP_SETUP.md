# GCP Setup Guide

Complete guide to setting up GRACE benchmarks on Google Cloud Platform.

## Prerequisites

### 1. GCP Account
- Create account: https://console.cloud.google.com/
- New users get $300 free credits (90 days)
- Always Free tier: 1 e2-micro instance per month (US regions)

### 2. Create GCP Project
```bash
# Via Console
# 1. Go to: https://console.cloud.google.com/projectcreate
# 2. Enter project name: "grace-benchmark"
# 3. Note the Project ID (e.g., grace-benchmark-123456)

# Via CLI
gcloud projects create grace-benchmark-$(date +%s) --name="GRACE Benchmark"
```

### 3. Enable Billing
```bash
# Link billing account (required even for free tier)
# https://console.cloud.google.com/billing/linkedaccount
```

### 4. Install Tools

#### macOS
```bash
# gcloud CLI
brew install google-cloud-sdk

# Terraform
brew install terraform

# jq (JSON processor)
brew install jq
```

#### Linux
```bash
# gcloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# jq
sudo apt-get install jq  # Debian/Ubuntu
sudo yum install jq      # RHEL/CentOS
```

---

## Authentication

### Method 1: User Account (Recommended for personal use)
```bash
# Login to GCP
gcloud auth login

# Set default credentials for Terraform
gcloud auth application-default login

# Set your project
gcloud config set project YOUR_PROJECT_ID

# Verify
gcloud auth list
gcloud config list
```

### Method 2: Service Account (Recommended for automation)
```bash
# Create service account
gcloud iam service-accounts create grace-sa \
    --display-name="GRACE Benchmark Service Account"

# Grant necessary roles
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:grace-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/compute.admin"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="serviceAccount:grace-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountUser"

# Create and download key
gcloud iam service-accounts keys create ~/grace-sa-key.json \
    --iam-account=grace-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS=~/grace-sa-key.json
```

---

## SSH Key Setup

### Option 1: Use existing key
```bash
# Check if you have a key
ls ~/.ssh/id_rsa.pub
# or
ls ~/.ssh/google_compute_engine.pub

# Get the key content
cat ~/.ssh/id_rsa.pub
```

### Option 2: Generate new key
```bash
# Generate SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/google_compute_engine -C "your-email@example.com"

# Get public key
cat ~/.ssh/google_compute_engine.pub
```

### Format for terraform.tfvars
```hcl
# Your public key should look like:
ssh_public_key = "yourusername:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC... youremail@example.com"

# Format: "username:key-type key-content comment"
# - username: your local username (run: whoami)
# - key-type: ssh-rsa or ssh-ed25519
# - key-content: the long string starting with AAAA...
# - comment: usually your email
```

---

## Enable Required APIs

```bash
# Enable Compute Engine API
gcloud services enable compute.googleapis.com

# Enable Cloud Resource Manager API
gcloud services enable cloudresourcemanager.googleapis.com

# List enabled services
gcloud services list --enabled
```

---

## Configure terraform.tfvars

```bash
cd gcp-deployment/terraform

# Copy example
cp terraform.tfvars.example terraform.tfvars

# Edit the file
nano terraform.tfvars
```

**Required settings:**
```hcl
# Your GCP project ID (REQUIRED)
project_id = "grace-benchmark-123456"

# Your SSH public key (REQUIRED)
# Get it: cat ~/.ssh/id_rsa.pub
ssh_public_key = "yourusername:ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC... you@host"

# Machine type (choose based on phase)
machine_type = "e2-micro"        # FREE TIER: Testing
# machine_type = "n2-standard-8" # PRODUCTION: Benchmarks

# Your IP for SSH access (RECOMMENDED)
# Get it: curl ifconfig.me
allowed_ssh_ips = ["203.0.113.1/32"]  # Replace with your IP
```

---

## Deployment Steps

### 1. Initialize Terraform
```bash
cd gcp-deployment/scripts
chmod +x *.sh

cd ../terraform
terraform init
```

### 2. Validate Configuration
```bash
# Check for errors
terraform validate

# Preview what will be created
terraform plan
```

### 3. Deploy Infrastructure
```bash
cd ../scripts
./deploy-infrastructure.sh

# Review the plan
# Type 'yes' to confirm
```

**What gets created:**
- 3 Compute Engine instances (us-east1, us-west1, europe-west1)
- 1 Global VPC network
- 3 Regional subnets
- 4 Firewall rules
- All automatically configured with Docker, Python, Java

### 4. Verify Deployment
```bash
# Check instances are running
gcloud compute instances list --filter="labels.project=grace-benchmark"

# Test SSH access
gcloud compute ssh grace-us-east1 --zone=us-east1-b

# Or with your key
ssh -i ~/.ssh/google_compute_engine yourusername@EXTERNAL_IP
```

---

## Billing and Cost Control

### Set Up Budget Alerts
```bash
# Via Console
# 1. Go to: https://console.cloud.google.com/billing/budgets
# 2. Click "Create Budget"
# 3. Set amount: $50 (or your limit)
# 4. Set alerts at: 50%, 90%, 100%
# 5. Add your email

# Via CLI
gcloud billing budgets create \
    --billing-account=YOUR_BILLING_ACCOUNT_ID \
    --display-name="GRACE Benchmark Budget" \
    --budget-amount=50 \
    --threshold-rule=percent=50 \
    --threshold-rule=percent=90
```

### Monitor Costs
```bash
# Check current month costs
gcloud billing projects describe YOUR_PROJECT_ID \
    --format="table(billingAccountName, billingEnabled)"

# View cost breakdown (in Console)
# https://console.cloud.google.com/billing/reports
```

### Always Teardown
```bash
# Delete all resources
cd gcp-deployment/scripts
./teardown.sh

# Verify cleanup
./check-resources.sh
```

---

## Troubleshooting

### Error: "Project not found"
```bash
# List your projects
gcloud projects list

# Set the correct project
gcloud config set project YOUR_PROJECT_ID
```

### Error: "API not enabled"
```bash
# Enable Compute Engine API
gcloud services enable compute.googleapis.com

# Enable other required APIs
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable iam.googleapis.com
```

### Error: "Quota exceeded"
```bash
# Check your quotas
gcloud compute project-info describe --project=YOUR_PROJECT_ID \
    --format="table(quotas)"

# Request quota increase
# https://console.cloud.google.com/iam-admin/quotas
# Select: Compute Engine API → CPUs
# Click: "EDIT QUOTAS" → Request increase
```

### Error: "Permission denied (publickey)"
**Problem**: SSH key not configured correctly

**Solution 1**: Use gcloud SSH (no key needed)
```bash
gcloud compute ssh grace-us-east1 --zone=us-east1-b
```

**Solution 2**: Fix SSH key format
```bash
# Get your public key
cat ~/.ssh/id_rsa.pub

# Format should be:
# yourusername:ssh-rsa AAAAB3NzaC1yc2E... you@host

# Update terraform.tfvars with correct format
ssh_public_key = "yourusername:ssh-rsa AAAAB3..."
```

**Solution 3**: Add key to metadata
```bash
# Add SSH key directly to instance
gcloud compute instances add-metadata grace-us-east1 \
    --zone=us-east1-b \
    --metadata-from-file ssh-keys=~/.ssh/id_rsa.pub
```

### Error: "Insufficient Permission"
```bash
# Grant yourself necessary roles
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
    --member="user:your-email@example.com" \
    --role="roles/compute.admin"
```

---

## Region Selection

### Available Regions

| Region | Location | Free Tier | Latency from us-east1 |
|--------|----------|-----------|----------------------|
| us-east1 | South Carolina | ✅ Yes | 0ms |
| us-west1 | Oregon | ✅ Yes | ~30ms |
| us-central1 | Iowa | ✅ Yes | ~20ms |
| europe-west1 | Belgium | ❌ No | ~90ms |
| asia-east1 | Taiwan | ❌ No | ~180ms |

**Current Setup**: us-east1, us-west1, europe-west1

**To change regions**: Edit `terraform/main.tf` and update the `region` and `zone` in each module block.

---

## Security Best Practices

### 1. Restrict SSH Access
```hcl
# In terraform.tfvars
allowed_ssh_ips = ["YOUR_IP/32"]  # Only your IP
```

### 2. Use Service Accounts
```bash
# Don't use personal credentials for automation
# Create a service account instead (see Authentication section)
```

### 3. Enable OS Login (Optional)
```bash
# Centralized SSH key management
gcloud compute project-info add-metadata \
    --metadata enable-oslogin=TRUE
```

### 4. Firewall Rules
```bash
# Review rules
gcloud compute firewall-rules list --filter="network:grace-network"

# Only allow necessary ports
# SSH: 22
# Application: 3000, 7000-7001, 7474, 7687, 8529, 27017, 9042
```

---

## Cleanup Checklist

Before closing your terminal or ending work:

```bash
# 1. Stop application
cd ~/grace/ReplicatedGDB
python3 Deployment.py down

# 2. Delete infrastructure
cd /path/to/gcp-deployment/scripts
./teardown.sh

# 3. Verify cleanup
./check-resources.sh

# 4. Check billing
gcloud compute instances list
# Should be empty

# 5. Optional: Delete project (removes everything)
gcloud projects delete YOUR_PROJECT_ID
```

---

## Quick Reference

```bash
# List instances
gcloud compute instances list

# SSH to instance
gcloud compute ssh INSTANCE_NAME --zone=ZONE

# Stop instance (saves cost, keeps data)
gcloud compute instances stop INSTANCE_NAME --zone=ZONE

# Start instance
gcloud compute instances start INSTANCE_NAME --zone=ZONE

# Delete instance
gcloud compute instances delete INSTANCE_NAME --zone=ZONE

# View logs
gcloud compute instances get-serial-port-output INSTANCE_NAME --zone=ZONE

# Check costs
# Console: https://console.cloud.google.com/billing/reports
```

---

## Support Resources

- **GCP Documentation**: https://cloud.google.com/docs
- **GCP Free Tier**: https://cloud.google.com/free
- **Pricing Calculator**: https://cloud.google.com/products/calculator
- **Terraform GCP Provider**: https://registry.terraform.io/providers/hashicorp/google/latest/docs
- **gcloud CLI Reference**: https://cloud.google.com/sdk/gcloud/reference

---

## Next Steps

1. ✅ Complete authentication (`gcloud auth login`)
2. ✅ Create/configure `terraform.tfvars`
3. ✅ Deploy infrastructure (`./deploy-infrastructure.sh`)
4. ✅ Deploy application (`./deploy-application.sh`)
5. ✅ Run benchmarks
6. ✅ **Always teardown!** (`./teardown.sh`)
