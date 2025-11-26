#!/bin/bash
# Configure Docker daemon to use TLS
# Usage: ./configure_docker_tls.sh <proxmox_host> <container_id> <certs_dir>

set -e

PROXMOX_HOST="${1:-192.168.3.2}"
CONTAINER_ID="${2:-100}"
CERTS_DIR="${3:-./certs}"

if [ -z "$PROXMOX_HOST" ] || [ -z "$CONTAINER_ID" ] || [ -z "$CERTS_DIR" ]; then
    echo "Usage: $0 <proxmox_host> <container_id> <certs_dir>"
    exit 1
fi

if [ ! -d "$CERTS_DIR" ]; then
    echo "Error: Certificates directory $CERTS_DIR not found"
    exit 1
fi

# Copy certificates to container
echo "Copying certificates to container..."
ssh -o StrictHostKeyChecking=no "root@${PROXMOX_HOST}" \
    "pct push ${CONTAINER_ID} ${CERTS_DIR}/ca.pem /etc/docker/ca.pem && \
     pct push ${CONTAINER_ID} ${CERTS_DIR}/server.pem /etc/docker/server.pem && \
     pct push ${CONTAINER_ID} ${CERTS_DIR}/server-key.pem /etc/docker/server-key.pem"

# Configure Docker daemon
echo "Configuring Docker daemon..."
ssh -o StrictHostKeyChecking=no "root@${PROXMOX_HOST}" \
    "pct exec ${CONTAINER_ID} -- sh -c '
        mkdir -p /etc/docker && \
        cat > /etc/docker/daemon.json <<EOF
{
  \"hosts\": [\"unix:///var/run/docker.sock\", \"tcp://0.0.0.0:2376\"],
  \"tls\": true,
  \"tlsverify\": true,
  \"tlscacert\": \"/etc/docker/ca.pem\",
  \"tlscert\": \"/etc/docker/server.pem\",
  \"tlskey\": \"/etc/docker/server-key.pem\"
}
EOF
    '"

# Restart Docker
echo "Restarting Docker daemon..."
ssh -o StrictHostKeyChecking=no "root@${PROXMOX_HOST}" \
    "pct exec ${CONTAINER_ID} -- rc-service docker restart"

echo "Docker TLS configuration complete!"
echo "Docker daemon is now listening on tcp://<container-ip>:2376 with TLS"

