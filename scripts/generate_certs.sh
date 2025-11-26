#!/bin/bash
# Generate TLS certificates for Docker daemon and Infisical
# Usage: ./generate_certs.sh <output_dir> <docker_host_ip>

set -e

OUTPUT_DIR="${1:-./certs}"
DOCKER_HOST="${2:-192.168.3.115}"

if [ -z "$OUTPUT_DIR" ] || [ -z "$DOCKER_HOST" ]; then
    echo "Usage: $0 <output_dir> <docker_host_ip>"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Generate CA
openssl genrsa -out "$OUTPUT_DIR/ca-key.pem" 4096
openssl req -new -x509 -days 365 -key "$OUTPUT_DIR/ca-key.pem" \
    -sha256 -out "$OUTPUT_DIR/ca.pem" \
    -subj "/C=BR/ST=SP/L=SP/O=Selfhost/CN=Selfhost-CA"

# Generate Docker daemon server certificate
openssl genrsa -out "$OUTPUT_DIR/server-key.pem" 4096
openssl req -subj "/C=BR/ST=SP/L=SP/O=Selfhost/CN=$DOCKER_HOST" \
    -sha256 -new -key "$OUTPUT_DIR/server-key.pem" -out "$OUTPUT_DIR/server.csr"

echo "subjectAltName = IP:$DOCKER_HOST,IP:127.0.0.1" > "$OUTPUT_DIR/extfile.cnf"
openssl x509 -req -days 365 -sha256 \
    -in "$OUTPUT_DIR/server.csr" \
    -CA "$OUTPUT_DIR/ca.pem" \
    -CAkey "$OUTPUT_DIR/ca-key.pem" \
    -CAcreateserial \
    -out "$OUTPUT_DIR/server.pem" \
    -extfile "$OUTPUT_DIR/extfile.cnf"

# Generate Docker client certificate
openssl genrsa -out "$OUTPUT_DIR/key.pem" 4096
openssl req -subj '/C=BR/ST=SP/L=SP/O=Selfhost/CN=client' \
    -new -key "$OUTPUT_DIR/key.pem" -out "$OUTPUT_DIR/client.csr"

echo "extendedKeyUsage = clientAuth" > "$OUTPUT_DIR/extfile-client.cnf"
openssl x509 -req -days 365 -sha256 \
    -in "$OUTPUT_DIR/client.csr" \
    -CA "$OUTPUT_DIR/ca.pem" \
    -CAkey "$OUTPUT_DIR/ca-key.pem" \
    -CAcreateserial \
    -out "$OUTPUT_DIR/cert.pem" \
    -extfile "$OUTPUT_DIR/extfile-client.cnf"

# Generate Infisical server certificate
openssl genrsa -out "$OUTPUT_DIR/infisical-key.pem" 4096
openssl req -subj "/C=BR/ST=SP/L=SP/O=Selfhost/CN=$DOCKER_HOST" \
    -sha256 -new -key "$OUTPUT_DIR/infisical-key.pem" -out "$OUTPUT_DIR/infisical.csr"

echo "subjectAltName = IP:$DOCKER_HOST,IP:127.0.0.1,DNS:localhost" > "$OUTPUT_DIR/extfile-infisical.cnf"
openssl x509 -req -days 365 -sha256 \
    -in "$OUTPUT_DIR/infisical.csr" \
    -CA "$OUTPUT_DIR/ca.pem" \
    -CAkey "$OUTPUT_DIR/ca-key.pem" \
    -CAcreateserial \
    -out "$OUTPUT_DIR/infisical.pem" \
    -extfile "$OUTPUT_DIR/extfile-infisical.cnf"

# Cleanup temporary files
rm -f "$OUTPUT_DIR"/*.csr "$OUTPUT_DIR"/*.cnf

echo "Certificates generated in $OUTPUT_DIR:"
ls -lh "$OUTPUT_DIR"/*.pem

