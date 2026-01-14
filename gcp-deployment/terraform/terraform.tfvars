# GCP Project Configuration
project_id = "project-71a4f829-43ea-436f-be1"  # REQUIRED: Your GCP project ID

# SSH Access
# Format: "username:ssh-rsa AAAA... user@host"
# Get your key: cat ~/.ssh/id_rsa.pub (or your key file)
ssh_public_key = "pandey:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFWNjX7uUmyb7AQ/Q6v5c2moGIwRuoK/1uMFrV5c/BGw pandey@Ayushs-MacBook-Pro.local"

# Network Configuration
network_name = "grace-network"

# Allowed SSH source IPs (CIDR notation)
# Get your IP: curl ifconfig.me
# Examples:
#   Single IPv4: ["203.0.113.1/32"]
#   Single IPv6: ["2001:db8::1/128"]
#   Multiple:    ["203.0.113.1/32", "198.51.100.0/24"]
allowed_ssh_ips = ["0.0.0.0/0"]  # WARNING: Open to all! Change to your IP!

# === COST OPTIONS ===

# Option 1: FREE TIER (Always Free - e2-micro)
# - Machine: e2-micro (2 vCPU shared, 1GB RAM)
# - Disk: 30GB standard persistent disk
# - Cost: FREE (1 e2-micro per month per region in US regions)
# - Note: Only us-west1, us-central1, us-east1 are always-free eligible
machine_type = "e2-micro"
disk_size    = 30

# Option 2: DEVELOPMENT (Low Cost)
# - Machine: e2-standard-2 (2 vCPU, 8GB RAM)
# - Cost: ~$0.067/hour = ~$49/month (3 regions)
# machine_type = "e2-micro"
# disk_size    = 50

# Option 3: PRODUCTION (Recommended for benchmarks)
# - Machine: n2-standard-8 (8 vCPU, 32GB RAM)
# - Cost: ~$0.388/hour = ~$284/month (3 regions)
# machine_type = "e2-micro"
# disk_size    = 100

# Option 4: HIGH PERFORMANCE
# - Machine: c2-standard-8 (8 vCPU, 32GB RAM, compute-optimized)
# - Cost: ~$0.428/hour = ~$313/month (3 regions)
# machine_type = "e2-micro"
# disk_size    = 100
