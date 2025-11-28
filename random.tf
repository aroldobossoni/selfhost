# Generate random passwords for infrastructure

# Docker LXC container password (always generated)
resource "random_password" "docker_lxc" {
  length  = 16
  special = false  # Alpine LXC may have issues with special chars
}

# Infisical passwords (only when enabled)
resource "random_password" "infisical_admin" {
  count   = var.enable_infisical ? 1 : 0
  length  = 24
  special = true
}

resource "random_password" "postgres" {
  count   = var.enable_infisical ? 1 : 0
  length  = 32
  special = false
}

resource "random_bytes" "encryption_key" {
  count   = var.enable_infisical ? 1 : 0
  length  = 16
}

resource "random_password" "jwt_signing_key" {
  count   = var.enable_infisical ? 1 : 0
  length  = 32
  special = false
}

# Convert encryption key bytes to hex string (32 chars for AES-256)
locals {
  # Docker LXC password
  docker_lxc_password = random_password.docker_lxc.result

  # Infisical passwords
  infisical_admin_password = var.enable_infisical && length(random_password.infisical_admin) > 0 ? random_password.infisical_admin[0].result : ""
  postgres_password         = var.enable_infisical && length(random_password.postgres) > 0 ? random_password.postgres[0].result : ""
  encryption_key_hex        = var.enable_infisical && length(random_bytes.encryption_key) > 0 ? random_bytes.encryption_key[0].hex : ""
  jwt_signing_key           = var.enable_infisical && length(random_password.jwt_signing_key) > 0 ? random_password.jwt_signing_key[0].result : ""
}

