#!/bin/bash
# common.sh - Common utility functions

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [ "${DEBUG}" = "1" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Retry a command with exponential backoff
retry_command() {
    local max_attempts=$1
    shift
    local cmd="$@"
    
    local attempt=1
    local delay=1
    
    while [ $attempt -le $max_attempts ]; do
        if eval "$cmd"; then
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log_warn "Command failed (attempt $attempt/$max_attempts). Retrying in ${delay}s..."
            sleep $delay
            delay=$((delay * 2))
        fi
        
        attempt=$((attempt + 1))
    done
    
    log_error "Command failed after $max_attempts attempts"
    return 1
}

# Check if running in GCP Cloud Shell
is_cloud_shell() {
    [ ! -z "$CLOUD_SHELL" ]
}

# Get current timestamp
timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

# Create a backup of a file
backup_file() {
    local file=$1
    
    if [ -f "$file" ]; then
        local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        log_info "Backed up $file to $backup"
    fi
}

# Cleanup temporary files on exit
cleanup_temp_files() {
    if [ ! -z "$TEMP_FILES" ]; then
        rm -f $TEMP_FILES
    fi
}

trap cleanup_temp_files EXIT

# Print a separator line
print_separator() {
    echo "=================================================="
}

# Confirm action with user
confirm_action() {
    local prompt=$1
    local default=${2:-no}
    
    if [ "$default" = "yes" ]; then
        read -p "$prompt [Y/n]: " response
        response=${response:-yes}
    else
        read -p "$prompt [y/N]: " response
        response=${response:-no}
    fi
    
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Parse JSON value using jq
json_value() {
    local json=$1
    local key=$2
    
    echo "$json" | jq -r "$key"
}

# Calculate cost estimate
estimate_hourly_cost() {
    local machine_type=$1
    local count=$2
    
    local unit_cost
    case $machine_type in
        e2-micro)
            unit_cost=0.01
            ;;
        e2-small)
            unit_cost=0.02
            ;;
        e2-medium)
            unit_cost=0.04
            ;;
        n2-standard-2)
            unit_cost=0.10
            ;;
        n2-standard-4)
            unit_cost=0.19
            ;;
        n2-standard-8)
            unit_cost=0.39
            ;;
        n2-standard-16)
            unit_cost=0.78
            ;;
        *)
            unit_cost=0
            ;;
    esac
    
    echo "scale=2; $unit_cost * $count" | bc
}

# Format bytes to human readable
format_bytes() {
    local bytes=$1
    
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$(echo "scale=2; $bytes / 1024" | bc)KB"
    elif [ $bytes -lt 1073741824 ]; then
        echo "$(echo "scale=2; $bytes / 1048576" | bc)MB"
    else
        echo "$(echo "scale=2; $bytes / 1073741824" | bc)GB"
    fi
}

# Check if port is open
check_port() {
    local host=$1
    local port=$2
    local timeout=${3:-5}
    
    timeout $timeout bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null
    return $?
}

# Wait for port to be open
wait_for_port() {
    local host=$1
    local port=$2
    local max_attempts=${3:-30}
    
    log_info "Waiting for $host:$port..."
    
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if check_port "$host" "$port"; then
            log_info "Port $port is open ✓"
            return 0
        fi
        
        attempt=$((attempt + 1))
        sleep 10
    done
    
    log_error "Port $port failed to open after $max_attempts attempts"
    return 1
}
