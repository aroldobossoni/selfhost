# Generate random passwords for Infisical infrastructure

resource "random_password" "admin" {
  count   = var.enabled ? 1 : 0
  length  = 24
  special = true
}

resource "random_password" "postgres" {
  count   = var.enabled ? 1 : 0
  length  = 32
  special = false
}

resource "random_bytes" "encryption_key" {
  count  = var.enabled ? 1 : 0
  length = 16
}

resource "random_password" "jwt_signing_key" {
  count   = var.enabled ? 1 : 0
  length  = 32
  special = false
}

locals {
  # Generated passwords (empty if disabled)
  admin_password     = var.enabled && length(random_password.admin) > 0 ? random_password.admin[0].result : ""
  postgres_password  = var.enabled && length(random_password.postgres) > 0 ? random_password.postgres[0].result : ""
  encryption_key_hex = var.enabled && length(random_bytes.encryption_key) > 0 ? random_bytes.encryption_key[0].hex : ""
  jwt_signing_key    = var.enabled && length(random_password.jwt_signing_key) > 0 ? random_password.jwt_signing_key[0].result : ""
}


