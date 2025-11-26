#!/bin/bash
# Download LXC template if not exists
# Usage: ./download_template.sh <proxmox_host> <storage> <template_name>

set -e

PROXMOX_HOST="$1"
STORAGE="$2"
TEMPLATE_NAME="$3"

if [ -z "$PROXMOX_HOST" ] || [ -z "$STORAGE" ] || [ -z "$TEMPLATE_NAME" ]; then
    echo "Usage: $0 <proxmox_host> <storage> <template_name>"
    exit 1
fi

ssh -o StrictHostKeyChecking=no "root@${PROXMOX_HOST}" \
    "pveam list ${STORAGE} | grep -q '${TEMPLATE_NAME}' || pveam download ${STORAGE} ${TEMPLATE_NAME}"

