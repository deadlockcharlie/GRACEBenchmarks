#!/bin/bash
# teardown.sh - Clean up all GCP resources

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"
CONFIG_DIR="$SCRIPT_DIR/../config"
UTILS_DIR="$SCRIPT_DIR/utils"

# Source common utilities if available
if [ -f "$UTILS_DIR/common.sh" ]; then
    source "$UTILS_DIR/common.sh"
else
    # Colors
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
    
    log_info() {
        echo -e "${GREEN}[INFO]${NC} $1"
    }
    
    log_warn() {
        echo -e "${YELLOW}[WARN]${NC} $1"
    }
    
    log_error() {
        echo -e "${RED}[ERROR]${NC} $1"
    }
fi

# Default configuration
SSH_USER="${SSH_USER:-$(whoami)}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/google_compute_engine}"

# Auto-detect SSH key
detect_ssh_key() {
    if [ -z "$SSH_KEY_PATH" ]; then
        for path in ~/.ssh/google_compute_engine ~/.ssh/id_rsa ~/.ssh/id_ed25519; do
            expanded_path=$(eval echo "$path")
            if [ -f "$expanded_path" ]; then
                SSH_KEY_PATH="$expanded_path"
                break
            fi
        done
    fi
}

# Stop Docker containers on all instances
stop_containers() {
    log_info "Stopping Docker containers on all instances..."
    
    if [ ! -f "$CONFIG_DIR/terraform-outputs.json" ]; then
        log_warn "No instance information found, skipping container cleanup"
        return
    fi
    
    # Get instance IPs (bash 3.x compatible)
    IPS=($(jq -r '.instance_details.value | .[] | .public_ip' "$CONFIG_DIR/terraform-outputs.json"))
    
    # Build SSH command
    local ssh_cmd="ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    if [ -n "$SSH_KEY_PATH" ]; then
        ssh_cmd="$ssh_cmd -i $SSH_KEY_PATH"
    fi
    
    for ip in "${IPS[@]}"; do
        log_info "Stopping containers on $ip..."
        $ssh_cmd "${SSH_USER}@$ip" \
            "cd /home/${SSH_USER}/grace/ReplicatedGDB 2>/dev/null && \
             export PRELOAD_DATA=/home/${SSH_USER}/grace/PreloadData && \
             python3 Deployment.py down 2>/dev/null || true" || true
    done
    
    log_info "Containers stopped ✓"
}

# Destroy infrastructure
destroy_infrastructure() {
    log_info "Destroying GCP infrastructure..."
    
    cd "$TERRAFORM_DIR"
    
    # Check if Terraform state exists
    if [ ! -f "terraform.tfstate" ]; then
        log_warn "No Terraform state found, nothing to destroy"
        return
    fi
    
    log_warn "This will DELETE all GCP resources created by Terraform!"
    log_warn "This action CANNOT be undone!"
    echo ""
    read -p "Are you sure you want to destroy all resources? (type 'yes' to confirm): " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_warn "Teardown cancelled"
        exit 0
    fi
    
    terraform destroy -auto-approve
    
    log_info "Infrastructure destroyed ✓"
}

# Clean up local files
cleanup_local_files() {
    log_info "Cleaning up local configuration files..."
    
    rm -f "$CONFIG_DIR/terraform-outputs.json"
    rm -f "$CONFIG_DIR/gcp-distribution-config.json"
    rm -f "$CONFIG_DIR/ssh-config"
    rm -f "$TERRAFORM_DIR/tfplan"
    
    log_info "Local files cleaned ✓"
}

# Main execution
main() {
    log_info "=== GRACE GCP Teardown ==="
    
    detect_ssh_key
    
    stop_containers
    destroy_infrastructure
    cleanup_local_files
    
    log_info "=== Teardown Complete ==="
    log_info "All GCP resources have been removed"
}

main "$@"
