#!/bin/bash
# Install Docker and SSH on Alpine LXC container
# Usage: ./install_docker.sh <proxmox_ssh_user> <proxmox_host> <container_id> [install_compose]

set -e

PROXMOX_SSH_USER="$1"
PROXMOX_HOST="$2"
CONTAINER_ID="$3"
INSTALL_COMPOSE="${4:-true}"

if [ -z "$PROXMOX_SSH_USER" ] || [ -z "$PROXMOX_HOST" ] || [ -z "$CONTAINER_ID" ]; then
    echo "Usage: $0 <proxmox_ssh_user> <proxmox_host> <container_id> [install_compose]"
    exit 1
fi

# Wait for container to be ready
sleep 10

# Build package list (Docker + SSH)
PACKAGES="docker docker-cli openssh"
if [ "$INSTALL_COMPOSE" = "true" ]; then
    PACKAGES="$PACKAGES docker-compose"
fi

# Install Docker and SSH
ssh -o StrictHostKeyChecking=no "${PROXMOX_SSH_USER}@${PROXMOX_HOST}" \
    "pct exec ${CONTAINER_ID} -- sh -c '
        apk update && \
        apk add --no-cache ${PACKAGES} && \
        rc-update add docker boot && \
        rc-update add sshd boot && \
        ssh-keygen -A && \
        service docker start && \
        service sshd start
    '"

# Copy SSH public key from Proxmox host to container for passwordless access
ssh -o StrictHostKeyChecking=no "${PROXMOX_SSH_USER}@${PROXMOX_HOST}" \
    "pct exec ${CONTAINER_ID} -- sh -c '
        mkdir -p /root/.ssh && \
        chmod 700 /root/.ssh
    '"

# Get Proxmox host public key and add to container authorized_keys
ssh -o StrictHostKeyChecking=no "${PROXMOX_SSH_USER}@${PROXMOX_HOST}" \
    "cat /root/.ssh/id_rsa.pub | pct exec ${CONTAINER_ID} -- sh -c 'cat >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys'" 2>/dev/null || true

# Also add the local machine's public key if available
if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
    LOCAL_KEY=$(cat "$HOME/.ssh/id_rsa.pub")
    ssh -o StrictHostKeyChecking=no "${PROXMOX_SSH_USER}@${PROXMOX_HOST}" \
        "pct exec ${CONTAINER_ID} -- sh -c 'echo \"${LOCAL_KEY}\" >> /root/.ssh/authorized_keys'"
fi
