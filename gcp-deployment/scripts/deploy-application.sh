#!/bin/bash
# deploy-application.sh - Deploy GRACE application to GCP instances

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
        *)
            log_error "Unknown option: $1"
            echo "Usage: $0 [--database neo4j|mongodb|memgraph|arangodb] [--replicas 1|3]"
            exit 1
            ;;
    esac
done

# Load instance IPs
load_instance_ips

# Validate database type
case $DATABASE in
    neo4j|mongodb|memgraph|arangodb)
        ;;
    *)
        log_error "Unsupported database: $DATABASE"
        echo "Supported: neo4j, mongodb, memgraph, arangodb"
        exit 1
        ;;
esac

log_info "=== GRACE Application Deployment ==="
log_info "Database: $DATABASE"
log_info "Replicas: $REPLICAS"

# Copy project files to instances
deploy_project_files() {
    log_info "Deploying project files to all instances..."
    local config_file="$CONFIG_DIR/terraform-outputs.json"
    local instances=( $(jq -r '.instance_details.value | to_entries[] | "\(.key):\(.value.public_ip)"' "$config_file") )

    for instance_info in "${instances[@]}"; do
        IFS=':' read -r region ip <<< "$instance_info"
        log_info "Deploying to $region ($ip)..."

        # Create remote directory
        ssh_exec "$ip" "mkdir -p /home/$(whoami)/grace"
        
        # Rsync project files (exclude large/unnecessary files)
        rsync -avz --progress \
            --exclude '.git' \
            --exclude 'Results' \
            --exclude 'BenchmarkPlots' \
            --exclude 'JanusgraphServer/janusgraph-*' \
            --exclude 'GraphDBData/frb*' \
            --exclude 'GraphDBData/ldbc*' \
            --exclude 'node_modules' \
            --exclude '__pycache__' \
            --exclude '*.pyc' \
            --exclude '.terraform' \
            -e "ssh $SSH_OPTS -i ~/.ssh/google_compute_engine" \
            "$PROJECT_ROOT/" \
            "$(whoami)@$ip:/home/$(whoami)/grace/"


        log_info "$region deployment complete ✓"
    done

    log_info "Project files deployed to all instances ✓"
}

# Check dependencies on all instances
check_dependencies() {
    log_info "Checking dependencies on all instances..."
    local config_file="$CONFIG_DIR/terraform-outputs.json"
    local instances=( $(jq -r '.instance_details.value | to_entries[] | "\(.key):\(.value.public_ip)"' "$config_file") )
    
    for instance_info in "${instances[@]}"; do
        IFS=':' read -r region ip <<< "$instance_info"
        log_info "Checking dependencies on $region ($ip)..."
        
        # Create dependency check script
        ssh_exec "$ip" 'cat > /tmp/check_deps.sh << '"'"'EOF'"'"'
#!/bin/bash
set -e

echo "=== Checking Dependencies ==="

# Function to check if command exists
check_command() {
    local cmd=$1
    local package=$2
    if command -v $cmd > /dev/null 2>&1; then
        echo "✓ $cmd is installed"
        return 0
    else
        echo "✗ $cmd is missing (install: $package)"
        return 1
    fi
}

# Function to wait for dpkg lock
wait_for_dpkg() {
    local max_wait=60
    local wait_time=0
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
        if [ $wait_time -ge $max_wait ]; then
            echo "Warning: dpkg still locked after $max_wait seconds"
            return 1
        fi
        echo "Waiting for package manager lock... ($wait_time/$max_wait)"
        sleep 5
        wait_time=$((wait_time + 5))
    done
    return 0
}

missing_deps=0

# Check essential build tools
check_command "java" "openjdk-11-jdk" || missing_deps=$((missing_deps + 1))
check_command "mvn" "maven" || missing_deps=$((missing_deps + 1))
check_command "python3" "python3" || missing_deps=$((missing_deps + 1))
check_command "pip3" "python3-pip" || missing_deps=$((missing_deps + 1))
check_command "docker" "docker-ce" || missing_deps=$((missing_deps + 1))
check_command "curl" "curl" || missing_deps=$((missing_deps + 1))
check_command "jq" "jq" || missing_deps=$((missing_deps + 1))

# Check Java version
if command -v java > /dev/null 2>&1; then
    java_version=$(java -version 2>&1 | head -n 1 | awk -F '"'"'"'"'"'"'"'"' '"'"'{print $2}'"'"')
    if [[ $java_version == 11.* ]] || [[ $java_version == 1.8.* ]]; then
        echo "✓ Java version: $java_version (compatible)"
    else
        echo "⚠ Java version: $java_version (may have compatibility issues)"
    fi
fi

# Check Maven version
if command -v mvn > /dev/null 2>&1; then
    mvn_version=$(mvn -version 2>/dev/null | head -n 1 | awk '"'"'{print $3}'"'"')
    echo "✓ Maven version: $mvn_version"
fi

# Check Docker status
if command -v docker > /dev/null 2>&1; then
    if docker ps > /dev/null 2>&1; then
        echo "✓ Docker is working"
    else
        echo "⚠ Docker installed but not accessible (may need permission fix)"
        missing_deps=$((missing_deps + 1))
    fi
fi

# Check if startup script completed
if [ -f /tmp/user-data-complete ]; then
    echo "✓ System initialization completed"
else
    echo "⚠ System initialization may still be running"
fi

# Install missing dependencies if needed
if [ $missing_deps -gt 0 ]; then
    echo ""
    echo "Installing missing dependencies..."
    
    if wait_for_dpkg; then
        sudo apt-get update
        
        # Install missing packages
        if ! command -v java > /dev/null 2>&1; then
            sudo apt-get install -y openjdk-11-jdk
        fi
        
        if ! command -v mvn > /dev/null 2>&1; then
            sudo apt-get install -y maven
        fi
        
        if ! command -v python3 > /dev/null 2>&1; then
            sudo apt-get install -y python3
        fi
        
        if ! command -v pip3 > /dev/null 2>&1; then
            sudo apt-get install -y python3-pip
        fi
        
        if ! command -v docker > /dev/null 2>&1; then
            echo "Docker installation requires manual setup"
        else
            # Fix Docker permissions if needed
            if ! docker ps > /dev/null 2>&1; then
                sudo systemctl start docker || true
                sudo chmod 666 /var/run/docker.sock || true
                sudo usermod -aG docker $(whoami) || true
            fi
        fi
        
        if ! command -v curl > /dev/null 2>&1; then
            sudo apt-get install -y curl
        fi
        
        if ! command -v jq > /dev/null 2>&1; then
            sudo apt-get install -y jq
        fi
        
        echo "✓ Dependencies installation completed"
    else
        echo "✗ Cannot install dependencies - package manager is locked"
        exit 1
    fi
fi

# Final verification
echo ""
echo "=== Final Verification ==="
final_missing=0
check_command "java" "openjdk-11-jdk" || final_missing=$((final_missing + 1))
check_command "mvn" "maven" || final_missing=$((final_missing + 1))
check_command "python3" "python3" || final_missing=$((final_missing + 1))
check_command "docker" "docker-ce" || final_missing=$((final_missing + 1))

if [ $final_missing -eq 0 ]; then
    echo "✓ All required dependencies are available"
    exit 0
else
    echo "✗ $final_missing dependencies still missing"
    exit 1
fi
EOF'
        
        # Make script executable and run it
        ssh_exec "$ip" "chmod +x /tmp/check_deps.sh && bash /tmp/check_deps.sh"
        
        if [ $? -eq 0 ]; then
            log_info "$region: All dependencies verified ✓"
        else
            log_error "$region: Dependency check failed ✗"
            exit 1
        fi
    done
    
    log_info "Dependencies verified on all instances ✓"
}

# Setup database on each instance
setup_database() {
    log_info "Setting up $DATABASE replica on all instances..."
    local config_file="$CONFIG_DIR/terraform-outputs.json"
    local instances=( $(jq -r '.instance_details.value | to_entries[] | "\(.key):\(.value.public_ip)"' "$config_file") )
    for instance_info in "${instances[@]}"; do
        ssh_exec "$ip" "cd /home/$(whoami)/grace/ && \
            chmod +x RunBenchmark.sh && \
            ./RunBenchmark.sh"
    done
    # log_info "Setting up $DATABASE on all instances..."
    # local config_file="$CONFIG_DIR/terraform-outputs.json"
    # local instances=( $(jq -r '.instance_details.value | to_entries[] | "\(.key):\(.value.public_ip)"' "$config_file") )

    # local i=1
    # for instance_info in "${instances[@]}"; do
    #     IFS=':' read -r region ip <<< "$instance_info"
    #     log_info "Setting up $DATABASE on $region (replica $i)..."

    #     # Run database-specific setup
    #     ssh_exec "$ip" "cd /home/$(whoami)/grace/ReplicatedGDB && \
    #         chmod +x setup-*.sh && \
    #         ./setup-$DATABASE.sh $i"

    #     i=$((i + 1))
    # done

    # log_info "$DATABASE setup complete on all instances ✓"
}

# Start application containers
start_application() {
    log_info "Starting application containers..."
    local config_file="$CONFIG_DIR/terraform-outputs.json"
    local instances=( $(jq -r '.instance_details.value | to_entries[] | "\(.key):\(.value.public_ip)"' "$config_file") )

    local i=1
    for instance_info in "${instances[@]}"; do
        IFS=':' read -r region ip <<< "$instance_info"
        log_info "Starting application on $region (replica $i)..."

        ssh_exec "$ip" "cd /home/$(whoami)/grace/ReplicatedGDB && \
            docker-compose up -d app$i"

        i=$((i + 1))
    done

    log_info "Application containers started ✓"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    local config_file="$CONFIG_DIR/terraform-outputs.json"
    local instances=( $(jq -r '.instance_details.value | to_entries[] | "\(.key):\(.value.public_ip)"' "$config_file") )

    local all_healthy=true

    for instance_info in "${instances[@]}"; do
        IFS=':' read -r region ip <<< "$instance_info"

        # Check if container is running
        if ssh_exec "$ip" "docker ps | grep -q app"; then
            log_info "$region: Container running ✓"
        else
            log_error "$region: Container not running ✗"
            all_healthy=false
        fi

        # Check if application responds
        if ssh_exec "$ip" "curl -s http://localhost:3000/health &> /dev/null"; then
            log_info "$region: Health check passed ✓"
        else
            log_warn "$region: Health check failed (may need more time to start)"
        fi
    done

    if [ "$all_healthy" = false ]; then
        log_error "Some containers failed to start"
        exit 1
    fi

    log_info "Deployment verification complete ✓"
}

# Main execution
main() {
    deploy_project_files
    check_dependencies
    setup_database
    # start_application
    
    log_info "Waiting for applications to start..."
    sleep 30
    
    verify_deployment
    
    log_info "=== Application Deployment Complete ==="
    log_info "All replicas are running!"
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
    echo "  1. Run benchmarks: ./run-benchmark.sh"
    echo "  2. Monitor logs: ssh $(whoami)@<ip> 'docker logs -f app1'"
}

main "$@"
