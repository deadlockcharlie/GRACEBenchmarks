#!/bin/bash
# ssh-helper.sh - SSH utility functions for GCP instances


# SSH options for non-interactive use
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR"

# Instance IPs (populated by load_instance_ips)
INSTANCE_IP_US_EAST1=""
INSTANCE_IP_US_WEST1=""
INSTANCE_IP_EUROPE_WEST1=""

# Load instance IPs from terraform output
load_instance_ips() {
    local config_file="$CONFIG_DIR/terraform-outputs.json"
    
    if [ ! -f "$config_file" ]; then
        log_error "Terraform outputs not found: $config_file"
        echo "Run ./deploy-infrastructure.sh first"
        exit 1
    fi
    
    # Parse instance details from JSON
    INSTANCE_IP_US_EAST1=$(jq -r '.instance_details.value.us_east1.public_ip' "$config_file")
    INSTANCE_IP_US_WEST1=$(jq -r '.instance_details.value.us_west1.public_ip' "$config_file")
    INSTANCE_IP_EUROPE_WEST1=$(jq -r '.instance_details.value.europe_west1.public_ip' "$config_file")
    
    # Verify IPs were loaded
    if [ "$INSTANCE_IP_US_EAST1" = "null" ] || [ -z "$INSTANCE_IP_US_EAST1" ]; then
        log_error "Failed to load IP for us_east1"
        exit 1
    fi
    if [ "$INSTANCE_IP_US_WEST1" = "null" ] || [ -z "$INSTANCE_IP_US_WEST1" ]; then
        log_error "Failed to load IP for us_west1"
        exit 1
    fi
    if [ "$INSTANCE_IP_EUROPE_WEST1" = "null" ] || [ -z "$INSTANCE_IP_EUROPE_WEST1" ]; then
        log_error "Failed to load IP for europe_west1"
        exit 1
    fi
    
    log_info "Loaded instance IPs ✓"
}

# Execute command on remote instance
ssh_exec() {
    local host=$1
    shift
    local cmd="$@"
    
    local USERNAME=$(whoami)
    
    ssh $SSH_OPTS -i ~/.ssh/google_compute_engine "$USERNAME@$host" "$cmd"
}

# Copy file to remote instance
scp_to() {
    local host=$1
    local local_path=$2
    local remote_path=$3
    
    local USERNAME=$(whoami)
    
    scp $SSH_OPTS -i ~/.ssh/google_compute_engine "$local_path" "$USERNAME@$host:$remote_path"
}

# Copy file from remote instance
scp_from() {
    local host=$1
    local remote_path=$2
    local local_path=$3
    
    local USERNAME=$(whoami)
    
    scp $SSH_OPTS -i ~/.ssh/google_compute_engine "$USERNAME@$host:$remote_path" "$local_path"
}

# Execute command on all instances in parallel
ssh_exec_all() {
    local cmd="$@"
    
    log_info "Executing on all instances: $cmd"
    
    local pids=()
    
    ssh_exec "$INSTANCE_IP_US_EAST1" "$cmd" &
    pids+=($!)
    
    ssh_exec "$INSTANCE_IP_US_WEST1" "$cmd" &
    pids+=($!)
    
    ssh_exec "$INSTANCE_IP_EUROPE_WEST1" "$cmd" &
    pids+=($!)
    
    # Wait for all to complete
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    log_info "Command completed on all instances ✓"
}

# Test SSH connectivity to an instance
test_ssh() {
    local host=$1
    
    if ssh_exec "$host" "echo 'SSH OK'" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Wait for SSH to become available
wait_for_ssh() {
    local host=$1
    local max_attempts=${2:-30}
    local attempt=0
    
    log_info "Waiting for SSH access to $host..."
    
    while [ $attempt -lt $max_attempts ]; do
        if test_ssh "$host"; then
            log_info "SSH ready ✓"
            return 0
        fi
        
        attempt=$((attempt + 1))
        sleep 10
    done
    
    log_error "SSH failed to become available after $max_attempts attempts"
    return 1
}
