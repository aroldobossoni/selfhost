#!/bin/bash
# Intelligent Terraform apply script
# Automatically detects state and applies in correct sequence

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Check if required tools are installed
check_required_tools() {
    local missing_tools=()
    
    if ! command -v terraform &>/dev/null; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v tflint &>/dev/null; then
        missing_tools+=("tflint")
    fi
    
    if ! command -v shellcheck &>/dev/null; then
        missing_tools+=("shellcheck")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Install them before running this script."
        exit 1
    fi
    
    log_info "All required tools available: terraform, tflint, shellcheck"
}

# Ensure SSH key exists for local machine
ensure_ssh_key() {
    log_step "Checking SSH key..."
    
    local key_file=""
    
    # Check for existing keys
    if [ -f "$HOME/.ssh/id_ed25519" ]; then
        key_file="$HOME/.ssh/id_ed25519"
        log_info "SSH key exists: $key_file"
    elif [ -f "$HOME/.ssh/id_rsa" ]; then
        key_file="$HOME/.ssh/id_rsa"
        log_info "SSH key exists: $key_file"
    else
        # Generate new key
        log_info "No SSH key found. Generating ed25519 key..."
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -C "$(whoami)@$(hostname)"
        key_file="$HOME/.ssh/id_ed25519"
        log_info "SSH key generated: $key_file"
    fi
    
    # Export for use in other functions
    export SSH_PUBLIC_KEY
    SSH_PUBLIC_KEY=$(cat "${key_file}.pub")
}

# Copy SSH key to container via Proxmox
copy_ssh_key_to_container() {
    local proxmox_host="$1"
    local container_id="$2"
    
    log_step "Copying SSH key to container $container_id..."
    
    # Check if key already exists in container
    local existing_keys
    existing_keys=$(ssh -o StrictHostKeyChecking=no "root@${proxmox_host}" \
        "pct exec ${container_id} -- cat /root/.ssh/authorized_keys 2>/dev/null" || echo "")
    
    if echo "$existing_keys" | grep -q "$(echo "$SSH_PUBLIC_KEY" | awk '{print $2}')"; then
        log_info "SSH key already exists in container."
        return 0
    fi
    
    # Add key to container
    ssh -o StrictHostKeyChecking=no "root@${proxmox_host}" \
        "pct exec ${container_id} -- sh -c '
            mkdir -p /root/.ssh && \
            chmod 700 /root/.ssh && \
            echo \"${SSH_PUBLIC_KEY}\" >> /root/.ssh/authorized_keys && \
            chmod 600 /root/.ssh/authorized_keys
        '"
    
    log_info "SSH key copied to container."
}

# Run shellcheck on all shell scripts
run_shellcheck() {
    log_step "Running shellcheck on scripts..."
    
    local scripts=(scripts/*.sh apply.sh)
    local has_errors=false
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            if ! shellcheck -x "$script" 2>/dev/null; then
                log_error "shellcheck failed for: $script"
                has_errors=true
            fi
        fi
    done
    
    if [ "$has_errors" = true ]; then
        log_error "Fix shellcheck errors before applying."
        exit 1
    fi
    
    log_info "shellcheck passed!"
}

# Run tflint on terraform files
run_tflint() {
    log_step "Running tflint..."
    
    # Initialize tflint if needed
    if [ ! -f ".tflint.hcl" ]; then
        tflint --init 2>/dev/null || true
    fi
    
    if ! tflint --recursive --format compact; then
        log_error "tflint found issues. Fix them before applying."
        exit 1
    fi
    
    log_info "tflint passed!"
}

# Intelligent terraform init
terraform_init() {
    log_step "Checking Terraform initialization..."
    
    local needs_init=false
    local needs_upgrade=false
    
    # Check if .terraform directory exists
    if [ ! -d ".terraform" ]; then
        needs_init=true
        log_info "Terraform not initialized. Running init..."
    fi
    
    # Check if .terraform.lock.hcl exists and versions.tf changed
    if [ -f ".terraform.lock.hcl" ]; then
        # Compare lock file age with versions.tf
        if [ "versions.tf" -nt ".terraform.lock.hcl" ] || \
           [ "modules/docker_lxc/versions.tf" -nt ".terraform.lock.hcl" ] || \
           [ "modules/infisical/versions.tf" -nt ".terraform.lock.hcl" ]; then
            needs_upgrade=true
            log_info "Provider versions may have changed. Running init -upgrade..."
        fi
    fi
    
    # Check if any module source changed
    if [ -d ".terraform/modules" ]; then
        local modules_json=".terraform/modules/modules.json"
        if [ -f "$modules_json" ]; then
            # If main.tf is newer than modules.json, might need reinit
            if [ "main.tf" -nt "$modules_json" ]; then
                needs_init=true
                log_info "Module configuration may have changed. Running init..."
            fi
        fi
    fi
    
    if [ "$needs_upgrade" = true ]; then
        terraform init -upgrade
    elif [ "$needs_init" = true ]; then
        terraform init
    else
        log_info "Terraform already initialized and up to date."
    fi
}

# Get docker_host_ip from terraform.tfvars
get_docker_host_ip() {
    grep -E "^docker_host_ip\s*=" terraform.tfvars 2>/dev/null | sed 's/.*=\s*"\([^"]*\)".*/\1/' | tr -d ' \r\n'
}

# Get pm_host from terraform.tfvars
get_pm_host() {
    grep -E "^pm_host\s*=" terraform.tfvars 2>/dev/null | sed 's/.*=\s*"\([^"]*\)".*/\1/' | tr -d ' \r\n'
}

# Get container ID from terraform state
get_container_id() {
    terraform output -raw docker_container_id 2>/dev/null | sed 's|proxmox/lxc/||'
}

# Check if SSH is available on docker host
check_ssh_available() {
    local host="$1"
    if [ -z "$host" ]; then
        return 1
    fi
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes "root@$host" "exit" 2>/dev/null
    return $?
}

# Check if Docker is available via SSH
check_docker_available() {
    local host="$1"
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "root@$host" "docker version" &>/dev/null
    return $?
}

# Check if Infisical API is available
check_infisical_available() {
    local host="$1"
    local port="${2:-8080}"
    # Check if API responds and returns 200 OK
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://${host}:${port}/api/status" 2>/dev/null)
    if [ "$status_code" = "200" ]; then
        # Also check if bootstrap endpoint is accessible (may return 400/404 if already bootstrapped, but connection works)
        curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://${host}:${port}/api/v1/admin/bootstrap" 2>/dev/null | grep -qE "(200|400|404|405)"
        return $?
    fi
    return 1
}

# Get infisical_port from terraform.tfvars
get_infisical_port() {
    grep -E "^infisical_port\s*=" terraform.tfvars 2>/dev/null | sed 's/.*=\s*\([0-9]*\).*/\1/' | tr -d ' \r\n' || echo "8080"
}

# Check if bootstrap token exists (now checks for client_id/secret)
check_bootstrap_token() {
    [ -f "infisical_token.auto.tfvars" ] && grep -q "infisical_client_id" "infisical_token.auto.tfvars" 2>/dev/null
    return $?
}

# Clean up orphaned Docker containers and networks
cleanup_docker_resources() {
    local host="$1"
    
    log_step "Cleaning up orphaned Docker resources..."
    
    # Stop and remove containers in the infisical network
    ssh -o StrictHostKeyChecking=no "root@$host" "
        # Find containers connected to infisical network
        CONTAINERS=\$(docker network inspect infisical --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || echo '')
        
        if [ -n \"\$CONTAINERS\" ]; then
            echo \"Stopping containers: \$CONTAINERS\"
            for container in \$CONTAINERS; do
                docker stop \"\$container\" 2>/dev/null || true
                docker rm -f \"\$container\" 2>/dev/null || true
            done
        fi
        
        # Force disconnect all containers from network
        docker network inspect infisical --format '{{range \$key, \$value := .Containers}}{{println \$key}}{{end}}' 2>/dev/null | while read container_id; do
            if [ -n \"\$container_id\" ]; then
                docker network disconnect -f infisical \"\$container_id\" 2>/dev/null || true
            fi
        done
        
        # Force remove network if it exists
        docker network rm infisical 2>/dev/null || true
    " || log_warn "Failed to cleanup Docker resources (may not exist)"
    
    log_info "Docker cleanup completed."
}

# Phase 3: Bootstrap Infisical
bootstrap_infisical() {
    local host="$1"
    local port="$2"
    
    log_step "Phase 3: Bootstrap Infisical..."
    
    # Check if already bootstrapped
    if check_bootstrap_token; then
        log_info "Infisical already configured (credentials file exists)."
        return 0
    fi
    
    # Ensure python3 and venv are available
    if ! command -v python3 &>/dev/null; then
        log_error "python3 is required but not installed."
        return 1
    fi

    # Setup virtual environment
    if [ ! -d ".venv" ]; then
        log_info "Creating Python virtual environment..."
        python3 -m venv .venv
    fi

    # Activate venv and install dependencies
    log_info "Installing Python dependencies..."
    # shellcheck source=/dev/null
    source .venv/bin/activate
    pip install --upgrade pip
    pip install requests pylint

    # Run pylint on configuration script
    log_info "Running pylint on configuration script..."
    if [ -f "scripts/configure_infisical.py" ]; then
        pylint --disable=C0111,C0103,W0702 scripts/configure_infisical.py || log_warn "Pylint found issues (non-fatal)"
    fi

    # Run bootstrap via Terraform
    log_info "Running bootstrap via Terraform (calls configuration script)..."
    # We target the null_resource that runs the python script
    # Terraform will use the activated venv because we sourced it
    if terraform apply -target=null_resource.configure_infisical -auto-approve; then
        if check_bootstrap_token; then
            log_info "Bootstrap completed successfully!"
            return 0
        else
            log_error "Bootstrap script finished but credentials file invalid or missing."
            return 1
        fi
    else
        log_error "Bootstrap failed. Check Terraform output for details."
        return 1
    fi
}

# Update enable_infisical in terraform.tfvars
set_enable_infisical() {
    local value="$1"
    if grep -q "^enable_infisical" terraform.tfvars 2>/dev/null; then
        sed -i "s/^enable_infisical.*/enable_infisical = $value/" terraform.tfvars
    else
        echo -e "\n# Infisical module toggle\nenable_infisical = $value" >> terraform.tfvars
    fi
}

# Get current enable_infisical value
get_enable_infisical() {
    grep -E "^enable_infisical\s*=" terraform.tfvars 2>/dev/null | grep -q "true" && echo "true" || echo "false"
}

# Main logic
main() {
    echo ""
    echo "=========================================="
    echo "  Terraform Intelligent Apply"
    echo "=========================================="
    echo ""

    # Step 1: Check required tools
    check_required_tools
    echo ""

    # Step 2: Ensure SSH key exists
    ensure_ssh_key
    echo ""

    # Step 3: Run linters
    run_shellcheck
    run_tflint
    echo ""

    # Step 4: Initialize terraform
    terraform_init
    echo ""

    # Step 5: Get docker host IP
    log_step "Checking deployment state..."
    DOCKER_HOST_IP=$(get_docker_host_ip)
    
    if [ -z "$DOCKER_HOST_IP" ]; then
        log_warn "docker_host_ip not set in terraform.tfvars"
        log_info "Applying docker_lxc module only (Phase 1 with -target)..."
        set_enable_infisical "false"
        # Use -target to avoid Docker provider initialization
        terraform apply -target=module.docker_lxc -auto-approve
        
        echo ""
        log_info "Phase 1 complete!"
        log_info "Get the container IP with: terraform output docker_container_ip"
        log_info "Or check via: ssh root@192.168.3.2 'pct exec 100 -- ip addr show eth0'"
        echo ""
        log_warn "Add docker_host_ip to terraform.tfvars and run this script again."
        exit 0
    fi

    log_info "Docker host IP: $DOCKER_HOST_IP"

    # Step 5: Check SSH availability
    log_step "Checking SSH connectivity to $DOCKER_HOST_IP..."
    if check_ssh_available "$DOCKER_HOST_IP"; then
        log_info "SSH is available!"
        
        # Check Docker availability
        if check_docker_available "$DOCKER_HOST_IP"; then
            log_info "Docker is available via SSH!"
            
            # Clean up any orphaned Docker resources before applying
            cleanup_docker_resources "$DOCKER_HOST_IP"
            
            # Check current state
            CURRENT_STATE=$(get_enable_infisical)
            if [ "$CURRENT_STATE" = "true" ]; then
                log_info "Infisical already enabled."
                # Check if bootstrap token exists
                if check_bootstrap_token; then
                    log_info "Bootstrap token exists. Running full apply..."
                    terraform apply -auto-approve
                else
                    log_info "Bootstrap token missing. Running Phase 2 (containers only)..."
                    # Use -refresh=false to avoid timeout issues with Docker resources
                    terraform apply -target=module.infisical -refresh=false -auto-approve || {
                        log_warn "Apply failed, cleaning up and retrying..."
                        cleanup_docker_resources "$DOCKER_HOST_IP"
                        terraform apply -target=module.infisical -auto-approve
                    }
                    # Run full apply to sync all resources and eliminate warnings
                    log_info "Syncing all resources..."
                    terraform apply -auto-approve
                fi
            else
                log_info "Enabling Infisical module (Phase 2 - containers only)..."
                set_enable_infisical "true"
                # Apply only Infisical containers, skip provider-dependent resources
                # Use -refresh=false to avoid timeout issues with Docker resources
                terraform apply -target=module.infisical -refresh=false -auto-approve || {
                    log_warn "Apply failed, cleaning up and retrying..."
                    cleanup_docker_resources "$DOCKER_HOST_IP"
                    terraform apply -target=module.infisical -auto-approve
                }
                # Run full apply to sync all resources and eliminate warnings
                log_info "Syncing all resources..."
                terraform apply -auto-approve
            fi
            
            # Phase 3: Bootstrap Infisical (if not already done)
            if ! check_bootstrap_token; then
                INFISICAL_PORT=$(get_infisical_port)
                bootstrap_infisical "$DOCKER_HOST_IP" "$INFISICAL_PORT"
            fi
            
            # Remove provider and resources files if token is not available to avoid initialization errors
            if [ -f "infisical_provider.tf" ] && ! check_bootstrap_token; then
                log_info "Removing Infisical provider (token not available)..."
                rm -f infisical_provider.tf
            fi
            if [ -f "infisical_resources.tf" ] && ! check_bootstrap_token; then
                log_info "Removing Infisical resources (token not available)..."
                rm -f infisical_resources.tf
            fi
            
            # Phase 4: Apply final resources (with Infisical provider)
            if check_bootstrap_token; then
                log_step "Phase 4: Enabling Infisical provider and applying resources..."
                # Verify token is actually set in the file
                if grep -q "infisical_token.*=" infisical_token.auto.tfvars 2>/dev/null && ! grep -q "infisical_token.*=\"\"" infisical_token.auto.tfvars 2>/dev/null; then
                    # Enable Infisical provider and resources by copying the example files
                    if [ ! -f "infisical_provider.tf" ] && [ -f "infisical_provider.tf.example" ]; then
                        cp infisical_provider.tf.example infisical_provider.tf
                        log_info "Infisical provider enabled."
                    fi
                    if [ ! -f "infisical_resources.tf" ] && [ -f "infisical_resources.tf.example" ]; then
                        cp infisical_resources.tf.example infisical_resources.tf
                        log_info "Infisical resources enabled."
                    fi
                    terraform init -upgrade
                    terraform apply -auto-approve
                else
                    log_warn "Token file exists but token is empty. Skipping Phase 4."
                    log_info "Run bootstrap manually or check Infisical logs."
                fi
            else
                log_info "Bootstrap not completed yet. Phase 4 skipped."
            fi
            
            echo ""
            echo "=========================================="
            echo "  Deployment Complete!"
            echo "=========================================="
            echo ""
            terraform output
        else
            log_error "SSH works but Docker is not responding"
            log_info "Try running: ssh root@$DOCKER_HOST_IP 'service docker start'"
            exit 1
        fi
    else
        log_warn "SSH not available on $DOCKER_HOST_IP"
        log_info "Applying docker_lxc module only (Phase 1 with -target)..."
        set_enable_infisical "false"
        # Use -target to avoid Docker provider initialization
        terraform apply -target=module.docker_lxc -auto-approve
        
        echo ""
        log_info "Phase 1 complete. Configuring SSH access..."
        
        # Get Proxmox Host and Container ID
        PM_HOST=$(get_pm_host)
        CONTAINER_ID=$(get_container_id)
        
        if [ -n "$PM_HOST" ] && [ -n "$CONTAINER_ID" ]; then
            copy_ssh_key_to_container "$PM_HOST" "$CONTAINER_ID"
        else
            log_warn "Could not auto-configure SSH (missing pm_host or container_id)"
        fi
        
        # Wait for SSH with progress
        log_info "Waiting for SSH to become available..."
        local max_attempts=30
        local attempt=0
        while [ $attempt -lt $max_attempts ]; do
            if check_ssh_available "$DOCKER_HOST_IP"; then
                echo ""
                log_info "SSH is now available!"
                
                # Wait a bit for Docker to be ready
                log_info "Waiting for Docker to be ready..."
                sleep 5
                
                if check_docker_available "$DOCKER_HOST_IP"; then
                    log_info "Docker is ready! Running Phase 2 automatically..."
                    set_enable_infisical "true"
                    terraform apply -auto-approve
                    
                    # Phase 3: Bootstrap Infisical
                    INFISICAL_PORT=$(get_infisical_port)
                    bootstrap_infisical "$DOCKER_HOST_IP" "$INFISICAL_PORT"
                    
                    # Phase 4: Apply final resources (with Infisical provider)
                    if check_bootstrap_token; then
                        log_step "Phase 4: Applying Infisical resources..."
                        terraform apply -auto-approve
                    fi
                    
                    echo ""
                    echo "=========================================="
                    echo "  Deployment Complete!"
                    echo "=========================================="
                    echo ""
                    terraform output
                    exit 0
                else
                    log_warn "Docker not ready yet. Run this script again in a moment."
                    exit 1
                fi
            fi
            echo -n "."
            sleep 2
            ((attempt++))
        done
        
        echo ""
        log_warn "SSH still not available after 60 seconds"
        log_info "Run this script again when SSH is ready."
        exit 1
    fi
}

# Run main function
main "$@"
