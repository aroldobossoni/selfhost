# Infisical resources managed via Terraform provider
# Only created when client_id and client_secret are available (after bootstrap)

locals {
  infisical_ready = var.enable_infisical && var.infisical_client_id != "" && var.infisical_client_secret != ""
}

# Create main project
resource "infisical_project" "selfhost" {
  count = local.infisical_ready ? 1 : 0
  name  = var.infisical_project_name
  slug  = var.infisical_project_name
}

# Store generated passwords as secrets in Infisical
resource "infisical_secret" "postgres_password" {
  count        = local.infisical_ready && length(infisical_project.selfhost) > 0 ? 1 : 0
  name         = "POSTGRES_PASSWORD"
  value        = local.postgres_password
  env_slug     = "development"
  workspace_id = infisical_project.selfhost[0].id
  folder_path  = "/"
}

resource "infisical_secret" "encryption_key" {
  count        = local.infisical_ready && length(infisical_project.selfhost) > 0 ? 1 : 0
  name         = "ENCRYPTION_KEY"
  value        = local.encryption_key_hex
  env_slug     = "development"
  workspace_id = infisical_project.selfhost[0].id
  folder_path  = "/"
}

resource "infisical_secret" "jwt_signing_key" {
  count        = local.infisical_ready && length(infisical_project.selfhost) > 0 ? 1 : 0
  name         = "JWT_SIGNING_KEY"
  value        = local.jwt_signing_key
  env_slug     = "development"
  workspace_id = infisical_project.selfhost[0].id
  folder_path  = "/"
}

resource "infisical_secret" "admin_password" {
  count        = local.infisical_ready && length(infisical_project.selfhost) > 0 ? 1 : 0
  name         = "ADMIN_PASSWORD"
  value        = local.infisical_admin_password
  env_slug     = "development"
  workspace_id = infisical_project.selfhost[0].id
  folder_path  = "/"
}

