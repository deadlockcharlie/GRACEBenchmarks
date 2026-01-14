#!/bin/bash
# deploy-with-images.sh - Deploy GRACE using pre-built images from GCR

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../config"
UTILS_DIR="$SCRIPT_DIR/utils"

# Source utility functions
source "$UTILS_DIR/ssh-helper.sh"
source "$UTILS_DIR/common.sh"

# Default parameters
DATABASE="neo4j"
REPLICAS=3
IMAGE_TAG="latest"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --database)
            DATABASE="$2"
            shift 2
            ;;
        --replicas)
            REPLICAS="$2"
            shift 2
            ;;
        --tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Usage: $0 [--database TYPE] [--replicas COUNT] [--tag TAG]"
            exit 1
            ;;
    esac
done

# Load instance IPs
load_instance_ips

log_info "=== GRACE Deployment with Pre-built Images ==="
log_info "Database: $DATABASE"
log_info "Replicas: $REPLICAS"
log_info "Image Tag: $IMAGE_TAG"

# Check if image manifest exists
check_image_manifest() {
    if [ ! -f "$CONFIG_DIR/image-manifest.json" ]; then
        log_error "Image manifest not found!"
        log_info "Please run: ./scripts/build-and-push-images.sh first"
        exit 1
    fi
    
    local manifest_database=$(jq -r '.database' "$CONFIG_DIR/image-manifest.json")
    local manifest_tag=$(jq -r '.image_tag' "$CONFIG_DIR/image-manifest.json")
    
    log_info "Found images built for: $manifest_database (tag: $manifest_tag)"
    
    if [ "$manifest_database" != "$DATABASE" ]; then
        log_warn "Manifest is for $manifest_database but deploying $DATABASE"
        read -p "Continue anyway? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            exit 0
        fi
    fi
}

# Configure GCR authentication on remote instances
configure_gcr_auth() {
    log_info "Configuring GCR authentication on all instances..."
    local config_file="$CONFIG_DIR/terraform-outputs.json"
    local instances=( $(jq -r '.instance_details.value | to_entries[] | "\(.key):\(.value.public_ip)"' "$config_file") )
    
    for instance_info in "${instances[@]}"; do
        IFS=':' read -r region ip <<< "$instance_info"
        log_info "Configuring GCR auth on $region..."
        
        # Install gcloud if not present and configure Docker
        ssh_exec "$ip" 'bash -s' << 'ENDSSH'
#!/bin/bash
set -e

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "Installing gcloud SDK..."
    curl -s https://sdk.cloud.google.com | bash -s -- --disable-prompts
    source ~/.bashrc
fi

# Configure Docker to use gcloud as credential helper for GCR
if [ ! -f ~/.docker/config.json ] || ! grep -q "gcr.io" ~/.docker/config.json; then
    echo "Configuring Docker for GCR..."
    gcloud auth configure-docker --quiet gcr.io
fi

# Alternative: Use docker login with access token (more reliable)
echo "Setting up GCR authentication..."
sudo chmod 666 /var/run/docker.sock || true
gcloud auth print-access-token 2>/dev/null || echo "Warning: gcloud auth may not be configured"

echo "GCR authentication configured"
ENDSSH
        
        log_info "$region: GCR auth configured ✓"
    done
}

# Pull images on all instances
pull_images() {
    log_info "Pulling images on all instances..."
    local config_file="$CONFIG_DIR/terraform-outputs.json"
    local instances=( $(jq -r '.instance_details.value | to_entries[] | "\(.key):\(.value.public_ip)"' "$config_file") )
    local project_id=$(jq -r '.project_id' "$CONFIG_DIR/image-manifest.json")
    
    local i=1
    for instance_info in "${instances[@]}"; do
        IFS=':' read -r region ip <<< "$instance_info"
        log_info "Pulling images for $region (replica $i)..."
        
        # Pull GRACE app image for this replica
        log_info "  Pulling GRACE app for replica $i..."
        ssh_exec "$ip" "sudo docker pull gcr.io/${project_id}/grace-app:replica${i}-${IMAGE_TAG}"
        
        # Pull WebSocket provider image for this replica
        log_info "  Pulling provider for replica $i..."
        ssh_exec "$ip" "sudo docker pull gcr.io/${project_id}/grace-wsserver:replica${i}-${IMAGE_TAG}"
        
        # Pull database image (memgraph or other)
        log_info "  Pulling database image..."
        case $DATABASE in
            memgraph)
                ssh_exec "$ip" "sudo docker pull memgraph/memgraph:latest"
                ssh_exec "$ip" "sudo docker pull memgraph/lab:latest"
                ;;
            neo4j)
                ssh_exec "$ip" "sudo docker pull neo4j:5.12-community"
                ;;
            mongodb)
                ssh_exec "$ip" "sudo docker pull mongo:6.0"
                ;;
            janusgraph)
                ssh_exec "$ip" "sudo docker pull gcr.io/${project_id}/grace-janusgraph:${IMAGE_TAG}"
                ;;
            arangodb)
                ssh_exec "$ip" "sudo docker pull arangodb:3.11"
                ;;
        esac
        
        log_info "$region: Images pulled ✓"
        i=$((i + 1))
    done
}

# Deploy configuration files and gcpDockerfiles
deploy_configs() {
    log_info "Deploying configuration files to all instances..."
    local config_file="$CONFIG_DIR/terraform-outputs.json"
    local instances=( $(jq -r '.instance_details.value | to_entries[] | "\(.key):\(.value.public_ip)"' "$config_file") )
    
    for instance_info in "${instances[@]}"; do
        IFS=':' read -r region ip <<< "$instance_info"
        log_info "Deploying configs to $region..."
        
        # Create remote directories
        ssh_exec "$ip" "mkdir -p /home/$(whoami)/grace/gcpDockerfiles"
        ssh_exec "$ip" "mkdir -p /home/$(whoami)/grace/Application"
        ssh_exec "$ip" "mkdir -p /home/$(whoami)/grace/PreloadData"
        
        # Copy gcpDockerfiles (compose files and dockerfiles)
        rsync -avz --progress \
            -e "ssh $SSH_OPTS -i ~/.ssh/google_compute_engine" \
            "$PROJECT_ROOT/gcpDockerfiles/" \
            "$(whoami)@$ip:/home/$(whoami)/grace/gcpDockerfiles/"
        
        # Copy Application code
        rsync -avz --progress \
            --exclude='node_modules' \
            --exclude='__pycache__' \
            --exclude='*.pyc' \
            -e "ssh $SSH_OPTS -i ~/.ssh/google_compute_engine" \
            "$PROJECT_ROOT/Application/" \
            "$(whoami)@$ip:/home/$(whoami)/grace/Application/"
        
        # Copy PreloadData if it exists
        if [ -d "$PROJECT_ROOT/PreloadData" ]; then
            rsync -avz --progress \
                -e "ssh $SSH_OPTS -i ~/.ssh/google_compute_engine" \
                "$PROJECT_ROOT/PreloadData/" \
                "$(whoami)@$ip:/home/$(whoami)/grace/PreloadData/"
        fi
        
        # Copy setup-latency.sh if it exists
        if [ -f "$PROJECT_ROOT/setup-latency.sh" ]; then
            rsync -avz \
                -e "ssh $SSH_OPTS -i ~/.ssh/google_compute_engine" \
                "$PROJECT_ROOT/setup-latency.sh" \
                "$(whoami)@$ip:/home/$(whoami)/grace/"
        fi
        
        log_info "$region: Configs deployed ✓"
    done
}

# Create network and deploy containers using gcpDockerfiles
deploy_containers() {
    log_info "Deploying containers on all instances..."
    local config_file="$CONFIG_DIR/terraform-outputs.json"
    local instances=( $(jq -r '.instance_details.value | to_entries[] | "\(.key):\(.value.public_ip)"' "$config_file") )
    local project_id=$(jq -r '.project_id' "$CONFIG_DIR/image-manifest.json")
    
    # Get all instance IPs for provider networking
    local instance_ips=()
    for instance_info in "${instances[@]}"; do
        IFS=':' read -r region ip <<< "$instance_info"
        instance_ips+=("$ip")
    done
    
    local i=1
    for instance_info in "${instances[@]}"; do
        IFS=':' read -r region ip <<< "$instance_info"
        log_info "Deploying to $region (replica $i)..."
        
        # Create the Shared_net network if it doesn't exist
        ssh_exec "$ip" "sudo docker network create Shared_net 2>/dev/null || true"
        
        # Update compose files to use GCR images
        ssh_exec "$ip" "cd /home/$(whoami)/grace && cat > docker-compose.${i}.yml" << EOF
name: GraceReplica${i}
services:
  memgraph${i}:
    image: memgraph/memgraph:latest
    container_name: memgraph${i}
    command: ["--log-level=TRACE"]
    pull_policy: always
    volumes:
      - /home/$(whoami)/grace/PreloadData:/var/lib/memgraph/import
    healthcheck:
      test: ["CMD-SHELL", "echo 'RETURN 0;' | mgconsole || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 0s
    ports:
      - "7687:7687"
    networks:
      - Shared_net

  lab${i}:
    image: memgraph/lab:latest
    pull_policy: always
    container_name: lab${i}
    depends_on:
      memgraph${i}:
        condition: service_healthy
    ports:
      - "7474:3000"
    environment:
      QUICK_CONNECT_MG_HOST: memgraph${i}
      QUICK_CONNECT_MG_PORT: 7687
    networks:
      - Shared_net

  app${i}:
    image: gcr.io/${project_id}/grace-app:replica${i}-${IMAGE_TAG}
    container_name: Grace${i}
    ports:
      - "3000:3000"
    environment:
      WS_URI: "ws://wsserver${i}:1234"
      DATABASE_URI: bolt://memgraph${i}:7687
      NEO4J_USER: "$(whoami)"
      NEO4J_PASSWORD: "verysecretpassword"
      USER: $(whoami)
      DATABASE: MEMGRAPH
      LOG_LEVEL: error
      REPLICA_ID: ${i}
    cap_add:
       - NET_ADMIN
    depends_on:
      memgraph${i}:
        condition: service_healthy
    networks:
      - Shared_net

  wsserver${i}:
    image: gcr.io/${project_id}/grace-wsserver:replica${i}-${IMAGE_TAG}
    container_name: wsserver${i}
    ports:
      - "1234:1234"
    environment:
      PORT: "1234"
      HOST: "0.0.0.0"
      REPLICA_ID: ${i}
      PEER_SERVERS: "$(echo ${instance_ips[@]} | sed 's/ /,/g')"
    cap_add:
       - NET_ADMIN
    networks:
      - Shared_net

networks:
  Shared_net:
     external: true
EOF
        
        # Start the containers
        log_info "Starting containers for replica $i..."
        ssh_exec "$ip" "cd /home/$(whoami)/grace && sudo docker compose -f docker-compose.${i}.yml up -d"
        
        log_info "$region: Replica $i deployed ✓"
        i=$((i + 1))
    done
    
    log_info "Waiting for all containers to stabilize..."
    sleep 30
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    local config_file="$CONFIG_DIR/terraform-outputs.json"
    local instances=( $(jq -r '.instance_details.value | to_entries[] | "\(.key):\(.value.public_ip)"' "$config_file") )
    
    local all_healthy=true
    local i=1
    
    for instance_info in "${instances[@]}"; do
        IFS=':' read -r region ip <<< "$instance_info"
        
        # Check if containers are running
        local expected_containers=("memgraph${i}" "lab${i}" "Grace${i}" "wsserver${i}")
        local running=0
        
        for container in "${expected_containers[@]}"; do
            if ssh_exec "$ip" "sudo docker ps --format '{{.Names}}' | grep -q '^${container}\$'"; then
                running=$((running + 1))
            else
                log_warn "$region: Container $container not running"
            fi
        done
        
        if [ "$running" -eq 4 ]; then
            log_info "$region (replica $i): All $running containers running ✓"
        else
            log_error "$region (replica $i): Only $running/4 containers running ✗"
            all_healthy=false
        fi
        
        # Check application health
        if ssh_exec "$ip" "curl -sf http://localhost:3000/health &> /dev/null"; then
            log_info "$region (replica $i): Health check passed ✓"
        else
            log_warn "$region (replica $i): Health check failed (app may need more time)"
        fi
        
        i=$((i + 1))
    done
    
    if [ "$all_healthy" = false ]; then
        log_error "Some deployments failed"
        exit 1
    fi
}

# Main execution
main() {
    check_image_manifest
    configure_gcr_auth
    pull_images
    deploy_configs
    deploy_containers
    verify_deployment
    
    log_info "=== Deployment Complete ==="
    log_info "All replicas are running with pre-built images!"
    log_info ""
    log_info "Access URLs:"
    local config_file="$CONFIG_DIR/terraform-outputs.json"
    local instances=( $(jq -r '.instance_details.value | to_entries[] | "\(.key):\(.value.public_ip)"' "$config_file") )
    
    for instance_info in "${instances[@]}"; do
        IFS=':' read -r region ip <<< "$instance_info"
        echo "  $region: http://$ip:3000"
    done
    echo ""
    log_info "Next steps:"
    echo "  1. Run benchmarks: ./scripts/run-benchmark.sh"
    echo "  2. View logs: ssh $(whoami)@<ip> 'cd grace && sudo docker compose logs -f'"
    echo "  3. Monitor: http://<ip>:9090 (Prometheus) or http://<ip>:5000 (Grafana)"
}

main "$@"
