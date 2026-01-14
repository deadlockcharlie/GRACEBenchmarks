#!/bin/bash
# deploy-infrastructure.sh - Deploy GCP infrastructure using Terraform

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"
CONFIG_DIR="$SCRIPT_DIR/../config"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform not found. Please install: https://www.terraform.io/downloads"
        exit 1
    fi
    
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI not found. Please install: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    # Check GCP authentication
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
        log_error "GCP credentials not configured!"
        echo ""
        echo "To fix this, run:"
        echo ""
        echo "  gcloud auth login"
        echo "  gcloud auth application-default login"
        echo "  gcloud config set project YOUR_PROJECT_ID"
        echo ""
        echo "Then enable required APIs:"
        echo "  gcloud services enable compute.googleapis.com"
        echo "  gcloud services enable cloudresourcemanager.googleapis.com"
        exit 1
    fi
    
    # Check if required APIs are enabled
    PROJECT_ID=$(gcloud config get-value project)
    if ! gcloud services list --enabled --project="$PROJECT_ID" | grep -q "compute.googleapis.com"; then
        log_warn "Compute API not enabled. Enabling now..."
        gcloud services enable compute.googleapis.com --project="$PROJECT_ID"
    fi
    
    log_info "GCP credentials configured ✓"
    log_info "Project: $PROJECT_ID"
    log_info "Prerequisites check passed ✓"
}

# Check if terraform.tfvars exists
check_tfvars() {
    if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
        log_error "terraform.tfvars not found!"
        log_info "Please create it from the example:"
        echo "    cp $TERRAFORM_DIR/terraform.tfvars.example $TERRAFORM_DIR/terraform.tfvars"
        echo "    # Edit terraform.tfvars and set your project_id and ssh_public_key"
        exit 1
    fi
}

# Initialize Terraform
init_terraform() {
    log_info "Initializing Terraform..."
    cd "$TERRAFORM_DIR"
    terraform init
    log_info "Terraform initialized ✓"
}

# Plan infrastructure
plan_infrastructure() {
    log_info "Planning infrastructure..."
    cd "$TERRAFORM_DIR"
    terraform plan -out=tfplan
    log_info "Plan created ✓"
    
    log_warn "Review the plan above carefully!"
    read -p "Do you want to proceed with deployment? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        log_warn "Deployment cancelled"
        exit 0
    fi
}

# Apply infrastructure
apply_infrastructure() {
    log_info "Deploying infrastructure... (this takes ~5 minutes)"
    cd "$TERRAFORM_DIR"
    terraform apply tfplan
    log_info "Infrastructure deployed ✓"
}

# Generate configuration files
generate_configs() {
    log_info "Generating configuration files..."
    cd "$TERRAFORM_DIR"
    
    # Export outputs to JSON
    terraform output -json > "$CONFIG_DIR/terraform-outputs.json"
    
    # Generate gcp-distribution-config.json
    terraform output -json distribution_config | jq '.' > "$CONFIG_DIR/gcp-distribution-config.json"
    
    # Generate SSH config
    local US_EAST1_IP=$(terraform output -json instance_details | jq -r '.value.us_east1.public_ip')
    local US_WEST1_IP=$(terraform output -json instance_details | jq -r '.value.us_west1.public_ip')
    local EUROPE_WEST1_IP=$(terraform output -json instance_details | jq -r '.value.europe_west1.public_ip')
    
    local USERNAME=$(whoami)
    
    cat > "$CONFIG_DIR/ssh-config" <<EOF
# SSH Config for GRACE GCP Instances
# Add to your ~/.ssh/config or use with: ssh -F config/ssh-config grace-us-east1

Host grace-us-east1
    HostName $US_EAST1_IP
    User $USERNAME
    IdentityFile ~/.ssh/google_compute_engine
    StrictHostKeyChecking no

Host grace-us-west1
    HostName $US_WEST1_IP
    User $USERNAME
    IdentityFile ~/.ssh/google_compute_engine
    StrictHostKeyChecking no

Host grace-europe-west1
    HostName $EUROPE_WEST1_IP
    User $USERNAME
    IdentityFile ~/.ssh/google_compute_engine
    StrictHostKeyChecking no

Host grace-*
    User $USERNAME
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
    
    log_info "Configuration files generated in $CONFIG_DIR/ ✓"
}

# Wait for instances to be ready
wait_for_instances() {
    log_info "Waiting for instances to complete initialization..."
    cd "$TERRAFORM_DIR"
    
    local USERNAME=$(whoami)
    
    # Get instance names and zones
    INSTANCES=($(terraform output -json instance_details | jq -r 'to_entries[] | "\(.value.instance_id):\(.value.zone)"'))
    
    for instance_info in "${INSTANCES[@]}"; do
        IFS=':' read -r instance_name zone <<< "$instance_info"
        log_info "Waiting for $instance_name in $zone..."
        max_attempts=60
        attempt=0
        
        while [ $attempt -lt $max_attempts ]; do
            status=$(gcloud compute instances describe "$instance_name" \
                --zone="$zone" \
                --format="value(status)" 2>/dev/null)
            
            if [ "$status" = "RUNNING" ]; then
                log_info "$instance_name is ready ✓"
                break
            fi
            
            attempt=$((attempt + 1))
            if [ $attempt -eq $max_attempts ]; then
                log_error "$instance_name failed to start (status: $status)"
                log_info "You can check the instance details with:"
                log_info "  gcloud compute instances describe $instance_name --zone=$zone"
                exit 1
            fi
            
            sleep 10
        done
    done
    
    log_info "All instances ready ✓"
}

# Main execution
main() {
    log_info "=== GRACE GCP Infrastructure Deployment ==="
    
    check_prerequisites
    check_tfvars
    init_terraform
    plan_infrastructure
    apply_infrastructure
    generate_configs
    wait_for_instances
    
    log_info "=== Deployment Complete ==="
    log_info "Next steps:"
    echo "  1. Review generated configs in $CONFIG_DIR/"
    echo "  2. Run: ./scripts/deploy-application.sh"
    echo "  3. Run benchmarks: ./scripts/run-benchmark.sh"
    echo ""
    log_warn "IMPORTANT: Remember to run ./scripts/teardown.sh when done to avoid GCP charges!"
}

main "$@"
