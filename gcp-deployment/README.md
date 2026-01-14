# GRACE GCP Deployment

Deploy the GRACE benchmark application to Google Cloud Platform with real geo-distributed latency across 3 regions.

## 🚀 One-Command Deployment

```bash
cd gcp-deployment
./quickstart.sh
```

**That's it!** The interactive script will:
- ✅ Check prerequisites (gcloud, terraform, jq)
- ✅ Verify GCP authentication
- ✅ Configure SSH keys automatically
- ✅ Let you choose deployment type (Free/Test/Production)
- ✅ Estimate costs
- ✅ Deploy infrastructure (~5 mins)
- ✅ Deploy application
- ✅ Show you next steps

**For detailed manual steps, see below.**

---

## Manual Deployment (Alternative)

### 1. Prerequisites

```bash
# Install gcloud CLI
brew install google-cloud-sdk  # macOS
# or https://cloud.google.com/sdk/docs/install

# Install Terraform
brew install terraform  # macOS
# or https://www.terraform.io/downloads

# Install jq
brew install jq

# Authenticate with GCP
gcloud auth login
gcloud auth application-default login

# Set your project
gcloud config set project YOUR_PROJECT_ID

# IMPORTANT: Enable required APIs (this prevents "Permission denied" errors)
gcloud services enable compute.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com

# Verify APIs are enabled
gcloud services list --enabled | grep compute
```

### 2. Setup SSH Key

```bash
# Generate SSH key (if you don't have one)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/google_compute_engine -C "your-email@example.com"

# Get your public key
cat ~/.ssh/google_compute_engine.pub
# Copy the output (starts with ssh-rsa)
```

### 3. Configure Terraform

```bash
cd gcp-deployment/terraform

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars
nano terraform.tfvars
```

Set these required values:
- `project_id`: Your GCP project ID
- `ssh_public_key`: Format: `"username:ssh-rsa AAAAB3... user@host"`
- `machine_type`: Start with `"e2-micro"` (FREE) or `"n2-standard-8"` (production)

### 4. Deploy Infrastructure

```bash
cd ../scripts

# Make scripts executable
chmod +x *.sh

# Deploy (takes ~5 minutes)
./deploy-infrastructure.sh
```

### 5. Deploy Application

```bash
./deploy-application.sh
```

### 6. Run Benchmarks

```bash
./run-benchmark.sh --dataset yeast --duration 300 --threads 32
```

### 7. Cleanup (IMPORTANT!)

```bash
# Always run this to avoid charges!
./teardown.sh

# Verify nothing is running
./check-resources.sh
```

---

## Architecture

### Regions (3-region setup)
- **us-east1** (South Carolina) - Primary
- **us-west1** (Oregon) - ~30ms from us-east1
- **europe-west1** (Belgium) - ~90ms from us-east1

### Instance Types

#### Free Tier (Always Free)
- **e2-micro**: 2 vCPU (shared), 1GB RAM
- **Cost**: FREE (1 instance per month in US regions)
- **Use**: Exploration, testing deployment

#### Production (Recommended)
- **n2-standard-8**: 8 vCPU, 32GB RAM
- **Cost**: ~$0.388/hour (~$1.16/hour for 3 regions)
- **Use**: Real benchmarks

### Network
- Global VPC with regional subnets (10.0.1.0/24, 10.1.1.0/24, 10.2.1.0/24)
- Firewall rules for SSH, inter-instance communication, and application ports
- Real inter-region latency (no simulation needed)

---

## Cost Management

### Free Tier Limits
- 1 e2-micro instance per month (US regions only: us-east1, us-central1, us-west1)
- 30GB standard persistent disk
- 1GB network egress (Americas)

### Production Costs (n2-standard-8)
- **Compute**: ~$0.388/hour × 3 = $1.16/hour
- **Storage**: ~$0.04/GB/month × 300GB = $12/month
- **Network**: ~$0.12/GB egress (after 1GB free)

**Example**: 8-hour benchmark = ~$10

### Cost Optimization
```bash
# Use free tier for testing
machine_type = "e2-micro"

# Upgrade for benchmarks
machine_type = "n2-standard-8"

# Always teardown when done!
./teardown.sh
```

---

## GCP vs AWS Comparison

| Feature | GCP | AWS |
|---------|-----|-----|
| Free Tier | e2-micro (1 per month) | t2.micro (750 hours/month) |
| CLI | gcloud | aws |
| Regions | us-east1, us-west1, europe-west1 | us-east-1, us-west-2, eu-central-1 |
| SSH | SSH keys in metadata | Key pairs |
| Network | Global VPC | Regional VPCs |
| Startup Script | metadata_startup_script | user_data |

---

## Commands

### Check Resources
```bash
# List all GRACE instances
gcloud compute instances list --filter="labels.project=grace-benchmark"

# Check costs
gcloud billing accounts list
gcloud billing projects describe YOUR_PROJECT_ID

# SSH to instance
gcloud compute ssh grace-us-east1 --zone=us-east1-b
# or
ssh -i ~/.ssh/google_compute_engine username@EXTERNAL_IP
```

### Manual Cleanup
```bash
# Delete specific instance
gcloud compute instances delete grace-us-east1 --zone=us-east1-b --quiet

# Delete all GRACE instances
gcloud compute instances list --filter="labels.project=grace-benchmark" --format="value(name,zone)" | \
  while read name zone; do gcloud compute instances delete $name --zone=$zone --quiet; done

# Delete network
gcloud compute networks delete grace-network --quiet
```

---

## Troubleshooting

### Error: "Project not set"
```bash
gcloud config set project YOUR_PROJECT_ID
```

### Error: "Permission denied (publickey)"
```bash
# Add your SSH key to terraform.tfvars
ssh_public_key = "yourusername:ssh-rsa AAAAB3NzaC... you@host"

# Or use gcloud SSH (no key needed)
gcloud compute ssh grace-us-east1 --zone=us-east1-b
```

### Error: "Quota exceeded"
```bash
# Check quotas
gcloud compute project-info describe --project=YOUR_PROJECT_ID

# Request quota increase
# https://console.cloud.google.com/iam-admin/quotas
```

### Error: "API not enabled"
```bash
# Enable required APIs
gcloud services enable compute.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
```

---

## Files

```
gcp-deployment/
├── terraform/
│   ├── main.tf                          # Main infrastructure
│   ├── variables.tf                     # Input variables
│   ├── outputs.tf                       # Output values
│   ├── terraform.tfvars.example         # Configuration template
│   └── modules/
│       ├── vpc/main.tf                  # VPC network
│       ├── firewall/main.tf             # Firewall rules
│       └── compute/main.tf              # Compute instances
├── scripts/
│   ├── deploy-infrastructure.sh         # Deploy GCP resources
│   ├── teardown.sh                      # Cleanup resources
│   ├── check-resources.sh               # Verify cleanup
│   ├── deploy-application.sh            # Deploy GRACE app
│   └── run-benchmark.sh                 # Execute benchmarks
├── config/
│   ├── terraform-outputs.json           # Generated Terraform outputs
│   ├── gcp-distribution-config.json     # Distribution config
│   └── ssh-config                       # SSH configuration
└── README.md                            # This file
```

---

## Security Best Practices

1. **Restrict SSH access**: Update `allowed_ssh_ips` in terraform.tfvars to your IP only
2. **Use private keys**: Never commit private keys to git
3. **Service accounts**: Use GCP service accounts for automation (not personal credentials)
4. **Firewall rules**: Review and restrict application ports as needed
5. **Budget alerts**: Set up billing alerts in GCP console

---

## Documentation

- **[Quick Reference](QUICK_REFERENCE.md)** - Common commands and troubleshooting
- **[GCP Setup Guide](GCP_SETUP.md)** - Detailed setup instructions
- **[AWS vs GCP Comparison](AWS_VS_GCP.md)** - Choose between AWS and GCP

---

## Next Steps

1. ✅ Deploy free tier (e2-micro) to test
2. ✅ Run small benchmark to verify setup
3. ✅ Upgrade to production instances (n2-standard-8)
4. ✅ Run full benchmarks
5. ✅ Collect results
6. ✅ **Teardown to avoid charges!**

---

## Support

- **Quick Reference:** [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
- **GCP Documentation:** https://cloud.google.com/docs
- **Terraform GCP Provider:** https://registry.terraform.io/providers/hashicorp/google/latest/docs
- **Compare AWS vs GCP:** [AWS_VS_GCP.md](AWS_VS_GCP.md)

---

## License

(Your license here)
