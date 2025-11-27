#!/bin/bash
# Download LXC template if not exists
# Usage: ./download_template.sh <proxmox_ssh_user> <proxmox_host> <storage> <template_name>

set -e

PROXMOX_SSH_USER="$1"
PROXMOX_HOST="$2"
STORAGE="$3"
TEMPLATE_NAME="$4"

if [ -z "$PROXMOX_SSH_USER" ] || [ -z "$PROXMOX_HOST" ] || [ -z "$STORAGE" ] || [ -z "$TEMPLATE_NAME" ]; then
    echo "Usage: $0 <proxmox_ssh_user> <proxmox_host> <storage> <template_name>"
    exit 1
fi

ssh -o StrictHostKeyChecking=no "${PROXMOX_SSH_USER}@${PROXMOX_HOST}" \
    "pveam list ${STORAGE} | grep -q '${TEMPLATE_NAME}' || pveam download ${STORAGE} ${TEMPLATE_NAME}"

