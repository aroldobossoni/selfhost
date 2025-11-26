#!/bin/bash
# Install Docker on Alpine LXC container
# Usage: ./install_docker.sh <proxmox_host> <container_id> [install_compose]

set -e

PROXMOX_HOST="$1"
CONTAINER_ID="$2"
INSTALL_COMPOSE="${3:-true}"

if [ -z "$PROXMOX_HOST" ] || [ -z "$CONTAINER_ID" ]; then
    echo "Usage: $0 <proxmox_host> <container_id> [install_compose]"
    exit 1
fi

# Wait for container to be ready
sleep 10

# Build package list
PACKAGES="docker docker-cli"
if [ "$INSTALL_COMPOSE" = "true" ]; then
    PACKAGES="$PACKAGES docker-compose"
fi

# Install Docker
ssh -o StrictHostKeyChecking=no "root@${PROXMOX_HOST}" \
    "pct exec ${CONTAINER_ID} -- sh -c 'apk update && apk add --no-cache ${PACKAGES} && rc-update add docker boot && service docker start'"

