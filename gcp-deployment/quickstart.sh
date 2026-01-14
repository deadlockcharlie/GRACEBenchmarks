#!/bin/bash
# quickstart.sh - Quick start guide for GCP deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   GRACE GCP Geo-Distributed Deployment         ║${NC}"
echo -e "${BLUE}║   Quick Start Guide                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Prerequisites
echo -e "${GREEN}Step 1: Checking Prerequisites${NC}"
echo "-------------------------------"

MISSING=()

if ! command -v terraform &> /dev/null; then
    MISSING+=("terraform")
fi

if ! command -v gcloud &> /dev/null; then
    MISSING+=("gcloud")
fi

if ! command -v jq &> /dev/null; then
    MISSING+=("jq")
fi

if [ ${#MISSING[@]} -gt 0 ]; then
    echo -e "${RED}✗ Missing required tools: ${MISSING[*]}${NC}"
    echo ""
    echo "Install instructions:"
    echo "  - Terraform: https://www.terraform.io/downloads"
    echo "  - gcloud CLI: https://cloud.google.com/sdk/docs/install"
    echo "  - jq: brew install jq (macOS) or apt install jq (Linux)"
    exit 1
else
    echo -e "${GREEN}✓ All prerequisites installed${NC}"
fi

# Check GCP authentication
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo -e "${RED}✗ GCP credentials not configured${NC}"
    echo ""
    echo -e "${YELLOW}Quick Setup:${NC}"
    echo "  1. Authenticate with GCP:"
    echo "     gcloud auth login"
    echo "     gcloud auth application-default login"
    echo ""
    echo "  2. Set your project:"
    echo "     gcloud config set project YOUR_PROJECT_ID"
    echo ""
    echo "  3. Enable required APIs:"
    echo "     gcloud services enable compute.googleapis.com"
    echo "     gcloud services enable cloudresourcemanager.googleapis.com"
    echo ""
    read -p "Do you want to configure GCP authentication now? (yes/no): " CONFIGURE
    if [ "$CONFIGURE" = "yes" ]; then
        gcloud auth login
        gcloud auth application-default login
        echo ""
        read -p "Enter your GCP project ID: " PROJECT_ID
        gcloud config set project "$PROJECT_ID"
        
        echo ""
        echo "Enabling required APIs..."
        gcloud services enable compute.googleapis.com
        gcloud services enable cloudresourcemanager.googleapis.com
        
        if gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
            echo -e "${GREEN}✓ GCP credentials configured successfully!${NC}"
        else
            echo -e "${RED}✗ Credential configuration failed. Please try again.${NC}"
            exit 1
        fi
    else
        exit 1
    fi
fi

if gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    echo -e "${GREEN}✓ GCP credentials configured${NC}"
    GCP_PROJECT=$(gcloud config get-value project)
    GCP_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    echo "  Account: $GCP_ACCOUNT"
    echo "  Project: $GCP_PROJECT"
fi

echo ""

# Step 2: SSH Key Setup
echo -e "${GREEN}Step 2: SSH Key Setup${NC}"
echo "----------------------"

SSH_KEY_PATH="$HOME/.ssh/google_compute_engine"
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${YELLOW}GCP SSH key not found${NC}"
    echo ""
    read -p "Generate SSH key now? (yes/no): " GEN_KEY
    if [ "$GEN_KEY" = "yes" ]; then
        read -p "Enter your email: " EMAIL
        ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -C "$EMAIL"
        echo -e "${GREEN}✓ SSH key generated${NC}"
    else
        echo -e "${RED}✗ SSH key required for GCP instances${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✓ SSH key found at $SSH_KEY_PATH${NC}"
fi

echo ""

# Step 3: Configuration
echo -e "${GREEN}Step 3: Configuration${NC}"
echo "----------------------"

if [ ! -f "$SCRIPT_DIR/terraform/terraform.tfvars" ]; then
    echo -e "${YELLOW}terraform.tfvars not found${NC}"
    echo ""
    echo "Creating from template..."
    cp "$SCRIPT_DIR/terraform/terraform.tfvars.example" "$SCRIPT_DIR/terraform/terraform.tfvars"
    
    # Auto-populate project_id
    if [ ! -z "$GCP_PROJECT" ]; then
        sed -i.bak "s/your-project-id/$GCP_PROJECT/g" "$SCRIPT_DIR/terraform/terraform.tfvars"
        rm "$SCRIPT_DIR/terraform/terraform.tfvars.bak"
        echo -e "${GREEN}✓ Auto-configured project_id: $GCP_PROJECT${NC}"
    fi
    
    # Auto-populate SSH key
    if [ -f "$SSH_KEY_PATH.pub" ]; then
        USERNAME=$(whoami)
        SSH_KEY_CONTENT=$(cat "$SSH_KEY_PATH.pub")
        SSH_KEY_LINE="$USERNAME:$SSH_KEY_CONTENT"
        
        # Escape special characters for sed
        SSH_KEY_ESCAPED=$(echo "$SSH_KEY_LINE" | sed 's/[\/&]/\\&/g')
        sed -i.bak "s/ssh_public_key = \".*\"/ssh_public_key = \"$SSH_KEY_ESCAPED\"/g" "$SCRIPT_DIR/terraform/terraform.tfvars"
        rm "$SCRIPT_DIR/terraform/terraform.tfvars.bak"
        echo -e "${GREEN}✓ Auto-configured SSH key${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}IMPORTANT: Review terraform/terraform.tfvars!${NC}"
    echo ""
    echo "Configuration:"
    echo "  1. project_id - Auto-configured"
    echo "  2. ssh_public_key - Auto-configured"
    echo "  3. allowed_ssh_ips - Set to your IP for security"
    echo "     Your IP: $(curl -s ifconfig.me 2>/dev/null || echo 'unknown')"
    echo ""
    read -p "Press Enter to continue..."
else
    echo -e "${GREEN}✓ terraform.tfvars found${NC}"
fi

# Check if project_id is set
PROJECT_ID=$(grep 'project_id' "$SCRIPT_DIR/terraform/terraform.tfvars" | cut -d'"' -f2)
if [ "$PROJECT_ID" == "your-project-id" ] || [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}✗ Please set project_id in terraform.tfvars${NC}"
    exit 1
fi

echo ""

# Step 4: Deployment Options
echo -e "${GREEN}Step 4: Choose Deployment Type${NC}"
echo "--------------------------------"
echo ""
echo "  1) Free Tier (3 regions, e2-micro, FREE for 1 instance/month)"
echo "  2) Quick Test (1 region, n2-standard-4, ~$0.19/hr)"
echo "  3) Standard Benchmark (3 regions, n2-standard-8, ~$1.15/hr)"
echo "  4) Custom"
echo "  5) Exit"
echo ""
read -p "Select option (1-5): " OPTION

case $OPTION in
    1)
        echo -e "${BLUE}Free Tier Deployment${NC}"
        echo -e "${YELLOW}Free Tier Limitations:${NC}"
        echo "  - e2-micro instances (0.25-2 vCPU shared, 1GB RAM)"
        echo "  - 1 non-preemptible e2-micro instance free per month"
        echo "  - 30GB standard persistent disk free per month"
        echo "  - Suitable for exploring deployment, NOT for benchmarks"
        echo "  - Upgrade to paid tier for actual performance testing"
        echo ""
        REPLICAS=3
        MACHINE_TYPE="e2-micro"
        ;;
    2)
        echo -e "${BLUE}Quick Test Deployment${NC}"
        REPLICAS=1
        MACHINE_TYPE="n2-standard-4"
        ;;
    3)
        echo -e "${BLUE}Standard Benchmark Deployment (All 3 Regions)${NC}"
        REPLICAS=3
        MACHINE_TYPE="n2-standard-8"
        ;;
    4)
        echo -e "${BLUE}Custom Deployment${NC}"
        read -p "Number of replicas (1-3): " REPLICAS
        read -p "Machine type (e.g., n2-standard-8): " MACHINE_TYPE
        ;;
    5)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo -e "${RED}✗ Invalid option${NC}"
        exit 1
        ;;
esac

echo ""
echo "Deployment Configuration:"
echo "  Replicas: $REPLICAS"
echo "  Machine Type: $MACHINE_TYPE"
echo ""

# Update terraform.tfvars with selected machine type
sed -i.bak "s/machine_type = \".*\"/machine_type = \"$MACHINE_TYPE\"/g" "$SCRIPT_DIR/terraform/terraform.tfvars"
rm "$SCRIPT_DIR/terraform/terraform.tfvars.bak"

# Step 5: Cost Estimation
echo -e "${YELLOW}Estimated Costs:${NC}"
case $MACHINE_TYPE in
    e2-micro)
        echo "  FREE TIER (1 instance free per month)"
        echo "  Additional instances: ~\$$(echo "$REPLICAS * 0.01" | bc)/hour"
        HOURLY="0.01 (1 free, others ~\$0.01/hr each)"
        ;;
    e2-small)
        HOURLY=$(echo "$REPLICAS * 0.02" | bc)
        ;;
    n2-standard-4)
        HOURLY=$(echo "$REPLICAS * 0.19" | bc)
        ;;
    n2-standard-8)
        HOURLY=$(echo "$REPLICAS * 0.39" | bc)
        ;;
    *)
        HOURLY="unknown"
        ;;
esac

if [ "$HOURLY" != "unknown" ] && [[ "$HOURLY" != *"free"* ]]; then
    DAILY=$(echo "$HOURLY * 24" | bc)
    echo "  Hourly: ~\$$HOURLY"
    echo "  Daily: ~\$$DAILY"
elif [[ "$HOURLY" == *"free"* ]]; then
    echo "  Cost: $HOURLY"
fi

echo -e "${YELLOW}Remember to run ./scripts/teardown.sh when done!${NC}"
echo ""

read -p "Proceed with deployment? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Cancelled"
    exit 0
fi

echo ""

# Step 6: Deploy Infrastructure
echo -e "${GREEN}Step 5: Deploying Infrastructure${NC}"
echo "-----------------------------------"
echo "This will take ~5-10 minutes..."
echo ""

cd "$SCRIPT_DIR/scripts"
chmod +x *.sh
chmod +x utils/*.sh 2>/dev/null || true

if ! ./deploy-infrastructure.sh; then
    echo -e "${RED}✗ Infrastructure deployment failed${NC}"
    exit 1
fi

echo ""

# Step 7: Deploy Application
echo -e "${GREEN}Step 6: Deploying Application${NC}"
echo "-------------------------------"
echo ""

read -p "Database type (neo4j/mongodb/memgraph/arangodb) [neo4j]: " DATABASE
DATABASE=${DATABASE:-neo4j}

if ! ./deploy-application.sh --database "$DATABASE" --replicas "$REPLICAS"; then
    echo -e "${RED}✗ Application deployment failed${NC}"
    exit 1
fi

echo ""

# Step 8: Success!
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Deployment Complete! ✓                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo "Your GRACE benchmark environment is ready!"
echo ""
echo "Next Steps:"
echo "  1. Run a test benchmark:"
echo "     cd $SCRIPT_DIR/scripts"
echo "     ./run-benchmark.sh --dataset yeast --duration 120 --threads 32"
echo ""
echo "  2. Collect results:"
echo "     ./collect-results.sh"
echo ""
echo "  3. SSH to instances:"
echo "     See: $SCRIPT_DIR/config/ssh-config"
echo ""
echo "  4. Monitor with Grafana:"
echo "     ssh -L 5000:localhost:5000 -i ~/.ssh/google_compute_engine user@<ip>"
echo "     Then open: http://localhost:5000"
echo ""
echo -e "${YELLOW}IMPORTANT: When done, clean up resources:${NC}"
echo "  cd $SCRIPT_DIR/scripts"
echo "  ./teardown.sh"
echo ""
echo "Documentation:"
echo "  - GCP Setup: $SCRIPT_DIR/GCP_SETUP.md"
echo "  - README: $SCRIPT_DIR/README.md"
echo ""
