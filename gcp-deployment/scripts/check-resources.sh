#!/bin/bash
# check-resources.sh - Check GCP resources and costs

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"

source "$UTILS_DIR/common.sh"

log_info "=== Checking GCP Resources ==="

# Check if gcloud is configured
if ! command -v gcloud &> /dev/null; then
    log_error "gcloud CLI not found"
    exit 1
fi

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    log_error "No GCP project configured"
    echo "Run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

log_info "Project: $PROJECT_ID"
echo ""

# Check Compute Engine instances
log_info "Compute Engine Instances:"
echo "-------------------------"
INSTANCES=$(gcloud compute instances list --filter="name~grace-" --format="table(name,zone,machineType,status,networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null || echo "")

if [ -z "$INSTANCES" ]; then
    log_info "No GRACE instances found ✓"
else
    echo "$INSTANCES"
    
    INSTANCE_COUNT=$(echo "$INSTANCES" | tail -n +2 | wc -l | tr -d ' ')
    log_warn "Found $INSTANCE_COUNT instance(s)"
    
    # Estimate costs
    echo ""
    log_info "Cost Estimation:"
    
    # Get machine types
    MACHINE_TYPES=$(gcloud compute instances list --filter="name~grace-" --format="value(machineType)" | awk -F'/' '{print $NF}')
    
    for machine in $MACHINE_TYPES; do
        case $machine in
            e2-micro)
                HOURLY="~\$0.01/hr (1 free per month)"
                ;;
            e2-small)
                HOURLY="~\$0.02/hr"
                ;;
            n2-standard-4)
                HOURLY="~\$0.19/hr"
                ;;
            n2-standard-8)
                HOURLY="~\$0.39/hr"
                ;;
            *)
                HOURLY="Check pricing"
                ;;
        esac
        echo "  $machine: $HOURLY"
    done
fi

echo ""

# Check VPC networks
log_info "VPC Networks:"
echo "-------------"
NETWORKS=$(gcloud compute networks list --filter="name~grace-" --format="table(name,subnet_mode)" 2>/dev/null || echo "")

if [ -z "$NETWORKS" ]; then
    log_info "No GRACE networks found ✓"
else
    echo "$NETWORKS"
fi

echo ""

# Check firewall rules
log_info "Firewall Rules:"
echo "---------------"
FIREWALLS=$(gcloud compute firewall-rules list --filter="name~grace-" --format="table(name,direction,priority,sourceRanges.list():label=SRC_RANGES)" 2>/dev/null || echo "")

if [ -z "$FIREWALLS" ]; then
    log_info "No GRACE firewall rules found ✓"
else
    echo "$FIREWALLS"
fi

echo ""

# Check for any billable resources
log_info "Summary:"
echo "--------"

TOTAL_INSTANCES=$(gcloud compute instances list --filter="name~grace-" --format="value(name)" 2>/dev/null | wc -l | tr -d ' ')
TOTAL_NETWORKS=$(gcloud compute networks list --filter="name~grace-" --format="value(name)" 2>/dev/null | wc -l | tr -d ' ')

if [ "$TOTAL_INSTANCES" -eq 0 ] && [ "$TOTAL_NETWORKS" -eq 0 ]; then
    log_info "✓ No GRACE resources found - no charges incurred"
else
    if [ "$TOTAL_INSTANCES" -gt 0 ]; then
        log_warn "⚠ $TOTAL_INSTANCES instance(s) running - COSTS ACCUMULATING"
        echo "    Run ./teardown.sh to stop charges"
    fi
    
    if [ "$TOTAL_NETWORKS" -gt 0 ]; then
        log_info "  $TOTAL_NETWORKS network(s) (minimal cost)"
    fi
fi

echo ""

# Check billing
log_info "Billing Information:"
echo "--------------------"
echo "View current costs: https://console.cloud.google.com/billing"
echo "Set budget alerts: https://console.cloud.google.com/billing/budgets"
echo ""
echo "To get cost summary via CLI:"
echo "  gcloud billing accounts list"
echo "  # Then use the account ID to view costs"
