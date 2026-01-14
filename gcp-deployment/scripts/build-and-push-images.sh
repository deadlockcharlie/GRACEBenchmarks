#!/bin/bash
# build-and-push-images.sh - Build Docker images locally and push to GCR

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_DIR="$SCRIPT_DIR/../config"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Default values
DATABASE="neo4j"
IMAGE_TAG="latest"
SKIP_BUILD=false
SKIP_PUSH=false

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--database)
                DATABASE="$2"
                shift 2
                ;;
            -t|--tag)
                IMAGE_TAG="$2"
                shift 2
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --skip-push)
                SKIP_PUSH=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build GRACE Docker images locally and push to Google Container Registry

Options:
    -d, --database TYPE     Database type (neo4j, mongodb, memgraph, etc) [default: neo4j]
    -t, --tag TAG          Image tag [default: latest]
    --skip-build           Skip building images (only push)
    --skip-push            Skip pushing images (only build)
    -h, --help             Show this help message

Examples:
    $0                                    # Build and push neo4j images
    $0 -d mongodb -t v1.0                # Build and push mongodb with tag v1.0
    $0 --skip-push                        # Only build locally
EOF
}

# Get GCP project ID
get_project_id() {
    if [ -f "$CONFIG_DIR/terraform-outputs.json" ]; then
        PROJECT_ID=$(jq -r '.project_id.value // empty' "$CONFIG_DIR/terraform-outputs.json")
    fi
    
    if [ -z "$PROJECT_ID" ]; then
        PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    fi
    
    if [ -z "$PROJECT_ID" ]; then
        log_error "Could not determine GCP project ID"
        log_info "Please run: gcloud config set project YOUR_PROJECT_ID"
        exit 1
    fi
    
    log_info "Using GCP project: $PROJECT_ID"
}

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker not found. Please install Docker."
        exit 1
    fi
    
    if ! docker ps &> /dev/null; then
        log_error "Docker is not running or you don't have permission."
        log_info "Try: sudo chmod 666 /var/run/docker.sock"
        exit 1
    fi
    
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI not found. Please install: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    # Check gcloud authentication
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
        log_error "Not authenticated with gcloud!"
        log_info "Run: gcloud auth login && gcloud auth configure-docker"
        exit 1
    fi
    
    log_info "Prerequisites check passed ✓"
}

# Configure Docker for GCR
configure_docker_for_gcr() {
    log_step "Configuring Docker for Google Container Registry..."
    
    # Configure Docker to use gcloud as credential helper
    gcloud auth configure-docker --quiet
    
    log_info "Docker configured for GCR ✓"
}

# Build GRACE application image from gcpDockerfiles
build_grace_app_image() {
    log_step "Building GRACE application image..."
    
    cd "$PROJECT_ROOT"
    
    local image_name="gcr.io/${PROJECT_ID}/grace-app"
    local image_full="${image_name}:${IMAGE_TAG}"
    
    # Check if gcpDockerfiles exists
    if [ ! -d "gcpDockerfiles" ]; then
        log_error "gcpDockerfiles directory not found!"
        exit 1
    fi
    
    # Build from GRACEDockerfile
    log_info "Building GRACE app from gcpDockerfiles/GRACEDockerfile..."
    docker build \
        -f gcpDockerfiles/GRACEDockerfile \
        -t "$image_full" \
        -t "${image_name}:latest" \
        .
    
    log_info "GRACE app image built ✓"
    echo "$image_full" > "$CONFIG_DIR/grace-app-image.txt"
}

# Build WebSocket server image for each replica
build_wsserver_image() {
    log_step "Building WebSocket server images for 3 replicas..."
    
    cd "$PROJECT_ROOT"
    
    # Build the base WSServer image from docker-compose.provider.yml
    log_info "Building provider from gcpDockerfiles/docker-compose.provider.yml..."
    docker compose -f gcpDockerfiles/docker-compose.provider.yml build
    
    # Tag for each replica
    for i in 1 2 3; do
        local image_name="gcr.io/${PROJECT_ID}/grace-wsserver"
        local image_full="${image_name}:replica${i}-${IMAGE_TAG}"
        
        # Tag the wsserver image for this replica
        docker tag provider-wsserver:latest "$image_full"
        docker tag provider-wsserver:latest "${image_name}:replica${i}-latest"
        
        log_info "Tagged provider for replica $i ✓"
    done
    
    # Also tag a generic latest
    docker tag provider-wsserver:latest "gcr.io/${PROJECT_ID}/grace-wsserver:${IMAGE_TAG}"
    docker tag provider-wsserver:latest "gcr.io/${PROJECT_ID}/grace-wsserver:latest"
    
    log_info "WebSocket server images built for all replicas ✓"
    echo "gcr.io/${PROJECT_ID}/grace-wsserver:${IMAGE_TAG}" > "$CONFIG_DIR/wsserver-image.txt"
}

# Build all replica images (for 3 replicas)
build_replica_images() {
    log_step "Building images for 3 replicas..."
    
    cd "$PROJECT_ROOT"
    
    # Build images from each replica compose file
    for i in 1 2 3; do
        local compose_file="gcpDockerfiles/docker-compose.${i}.yml"
        
        if [ ! -f "$compose_file" ]; then
            log_warn "Compose file not found: $compose_file"
            continue
        fi
        
        log_info "Building images from replica $i..."
        docker compose -f "$compose_file" build
        
        # Tag the built GRACE app image for this replica
        local app_service="app${i}"
        local app_image=$(docker compose -f "$compose_file" config --images | grep -i grace | head -1)
        
        if [ ! -z "$app_image" ]; then
            docker tag "$app_image" "gcr.io/${PROJECT_ID}/grace-app:replica${i}-${IMAGE_TAG}"
            log_info "Tagged replica $i image ✓"
        fi
    done
    
    log_info "All replica images built ✓"
}

# Build database-specific images if needed
build_database_images() {
    log_step "Checking database-specific images..."
    
    case $DATABASE in
        memgraph)
            log_info "Using official Memgraph image from compose files"
            ;;
        neo4j)
            log_info "Using official Neo4j image"
            ;;
        mongodb)
            log_info "Using official MongoDB image"
            ;;
        janusgraph)
            build_janusgraph_image
            ;;
        arangodb)
            log_info "Using official ArangoDB image"
            ;;
        *)
            log_warn "Unknown database: $DATABASE, using compose file defaults"
            ;;
    esac
}

# Build JanusGraph custom image
build_janusgraph_image() {
    log_info "Building custom JanusGraph image..."
    
    local image_name="gcr.io/${PROJECT_ID}/grace-janusgraph"
    local image_full="${image_name}:${IMAGE_TAG}"
    
    if [ -d "$PROJECT_ROOT/JanusgraphServer" ]; then
        cd "$PROJECT_ROOT/JanusgraphServer"
        
        if [ -f "Dockerfile" ]; then
            docker build -t "$image_full" -t "${image_name}:latest" .
            log_info "JanusGraph image built ✓"
            echo "$image_full" > "$CONFIG_DIR/janusgraph-image.txt"
        else
            log_warn "No Dockerfile found for JanusGraph, skipping custom build"
        fi
    fi
}

# Build netem (network emulation) image
build_netem_image() {
    log_step "Network emulation handled by compose files..."
    log_info "netem capabilities are included in GRACE app containers ✓"
}

# Push images to GCR
push_images_to_gcr() {
    log_step "Pushing images to Google Container Registry..."
    
    local images_pushed=0
    
    # Push GRACE app
    if [ -f "$CONFIG_DIR/grace-app-image.txt" ]; then
        local grace_image=$(cat "$CONFIG_DIR/grace-app-image.txt")
        log_info "Pushing $grace_image..."
        docker push "$grace_image"
        docker push "gcr.io/${PROJECT_ID}/grace-app:latest"
        images_pushed=$((images_pushed + 1))
        
        # Push replica-specific tags
        for i in 1 2 3; do
            local replica_tag="gcr.io/${PROJECT_ID}/grace-app:replica${i}-${IMAGE_TAG}"
            if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "$replica_tag"; then
                log_info "Pushing replica $i app image..."
                docker push "$replica_tag"
                images_pushed=$((images_pushed + 1))
            fi
        done
        
        log_info "GRACE app images pushed ✓"
    fi
    
    # Push WebSocket server for each replica
    if [ -f "$CONFIG_DIR/wsserver-image.txt" ]; then
        local wsserver_image=$(cat "$CONFIG_DIR/wsserver-image.txt")
        log_info "Pushing $wsserver_image..."
        docker push "$wsserver_image"
        docker push "gcr.io/${PROJECT_ID}/grace-wsserver:latest"
        images_pushed=$((images_pushed + 1))
        
        # Push provider for each replica
        for i in 1 2 3; do
            local provider_tag="gcr.io/${PROJECT_ID}/grace-wsserver:replica${i}-${IMAGE_TAG}"
            local provider_latest="gcr.io/${PROJECT_ID}/grace-wsserver:replica${i}-latest"
            
            if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "$provider_tag"; then
                log_info "Pushing replica $i provider image..."
                docker push "$provider_tag"
                docker push "$provider_latest"
                images_pushed=$((images_pushed + 1))
            fi
        done
        
        log_info "WebSocket server images pushed ✓"
    fi
    
    # Push JanusGraph if built
    if [ -f "$CONFIG_DIR/janusgraph-image.txt" ]; then
        local janus_image=$(cat "$CONFIG_DIR/janusgraph-image.txt")
        log_info "Pushing $janus_image..."
        docker push "$janus_image"
        docker push "gcr.io/${PROJECT_ID}/grace-janusgraph:latest"
        images_pushed=$((images_pushed + 1))
        log_info "JanusGraph image pushed ✓"
    fi
    
    log_info "All images pushed to GCR ($images_pushed images) ✓"
}

# List pushed images
list_images() {
    log_step "Images available in GCR:"
    echo ""
    echo "GRACE Application (3 replicas):"
    echo "  gcr.io/${PROJECT_ID}/grace-app:${IMAGE_TAG}"
    echo "  gcr.io/${PROJECT_ID}/grace-app:latest"
    echo "  gcr.io/${PROJECT_ID}/grace-app:replica1-${IMAGE_TAG}"
    echo "  gcr.io/${PROJECT_ID}/grace-app:replica2-${IMAGE_TAG}"
    echo "  gcr.io/${PROJECT_ID}/grace-app:replica3-${IMAGE_TAG}"
    echo ""
    echo "WebSocket Providers (3 replicas - communicate with each other):"
    echo "  gcr.io/${PROJECT_ID}/grace-wsserver:${IMAGE_TAG}"
    echo "  gcr.io/${PROJECT_ID}/grace-wsserver:latest"
    echo "  gcr.io/${PROJECT_ID}/grace-wsserver:replica1-${IMAGE_TAG}"
    echo "  gcr.io/${PROJECT_ID}/grace-wsserver:replica2-${IMAGE_TAG}"
    echo "  gcr.io/${PROJECT_ID}/grace-wsserver:replica3-${IMAGE_TAG}"
    echo ""
    
    if [ "$DATABASE" = "janusgraph" ]; then
        echo "JanusGraph:"
        echo "  gcr.io/${PROJECT_ID}/grace-janusgraph:${IMAGE_TAG}"
        echo "  gcr.io/${PROJECT_ID}/grace-janusgraph:latest"
        echo ""
    fi
}

# Generate image manifest for deployment
generate_image_manifest() {
    log_step "Generating image manifest..."
    
    cat > "$CONFIG_DIR/image-manifest.json" << EOF
{
  "project_id": "$PROJECT_ID",
  "image_tag": "$IMAGE_TAG",
  "database": "$DATABASE",
  "replicas": 3,
  "images": {
    "grace_app": "gcr.io/${PROJECT_ID}/grace-app:${IMAGE_TAG}",
    "grace_app_latest": "gcr.io/${PROJECT_ID}/grace-app:latest",
    "grace_app_replica1": "gcr.io/${PROJECT_ID}/grace-app:replica1-${IMAGE_TAG}",
    "grace_app_replica2": "gcr.io/${PROJECT_ID}/grace-app:replica2-${IMAGE_TAG}",
    "grace_app_replica3": "gcr.io/${PROJECT_ID}/grace-app:replica3-${IMAGE_TAG}",
    "wsserver": "gcr.io/${PROJECT_ID}/grace-wsserver:${IMAGE_TAG}",
    "wsserver_latest": "gcr.io/${PROJECT_ID}/grace-wsserver:latest",
    "wsserver_replica1": "gcr.io/${PROJECT_ID}/grace-wsserver:replica1-${IMAGE_TAG}",
    "wsserver_replica2": "gcr.io/${PROJECT_ID}/grace-wsserver:replica2-${IMAGE_TAG}",
    "wsserver_replica3": "gcr.io/${PROJECT_ID}/grace-wsserver:replica3-${IMAGE_TAG}"
EOF
    
    if [ "$DATABASE" = "janusgraph" ]; then
        cat >> "$CONFIG_DIR/image-manifest.json" << EOF
,
    "janusgraph": "gcr.io/${PROJECT_ID}/grace-janusgraph:${IMAGE_TAG}",
    "janusgraph_latest": "gcr.io/${PROJECT_ID}/grace-janusgraph:latest"
EOF
    fi
    
    cat >> "$CONFIG_DIR/image-manifest.json" << EOF
  },
  "architecture": {
    "description": "Each replica has its own GRACE app and WebSocket provider",
    "replica_count": 3,
    "provider_communication": "All providers are networked together on Shared_net",
    "deployment_model": "Each GCP VM runs: 1 GRACE app + 1 provider + 1 database"
  },
  "built_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    log_info "Image manifest saved to: $CONFIG_DIR/image-manifest.json"
}

# Main execution
main() {
    log_info "=== GRACE Docker Image Build & Push ==="
    
    parse_args "$@"
    
    log_info "Database: $DATABASE"
    log_info "Image Tag: $IMAGE_TAG"
    
    get_project_id
    check_prerequisites
    configure_docker_for_gcr
    
    if [ "$SKIP_BUILD" = false ]; then
        build_grace_app_image
        build_wsserver_image
        build_replica_images
        build_database_images
        build_netem_image
    else
        log_warn "Skipping build (--skip-build specified)"
    fi
    
    if [ "$SKIP_PUSH" = false ]; then
        push_images_to_gcr
    else
        log_warn "Skipping push (--skip-push specified)"
    fi
    
    generate_image_manifest
    list_images
    
    log_info "=== Build & Push Complete ==="
    log_info "Next steps:"
    echo "  1. Deploy to GCP instances: ./scripts/deploy-with-images.sh"
    echo "  2. Or update existing deployment: ./scripts/deploy-application.sh --use-gcr"
    echo ""
    log_warn "Images in GCR incur storage costs (~$0.026/GB/month)"
    log_info "To delete images: gcloud container images delete gcr.io/${PROJECT_ID}/grace-app:${IMAGE_TAG}"
}

main "$@"
