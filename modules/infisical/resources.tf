# Infisical resources (projects, secrets)
# Only created when client_id and client_secret are available (after bootstrap)

locals {
  infisical_ready = var.enabled && var.client_id != "" && var.client_secret != ""
}

# Create main project
resource "infisical_project" "main" {
  count = local.infisical_ready ? 1 : 0
  name  = var.project_name
  slug  = var.project_name
}

# Create development environment
resource "infisical_project_environment" "development" {
  count = local.infisical_ready && length(infisical_project.main) > 0 ? 1 : 0

  project_id = infisical_project.main[0].id
  name       = "Development"
  slug       = "development"
}

# Store generated passwords as secrets in Infisical
resource "infisical_secret" "postgres_password" {
  count        = local.infisical_ready && length(infisical_project_environment.development) > 0 ? 1 : 0
  name         = "POSTGRES_PASSWORD"
  value        = local.postgres_password
  env_slug     = infisical_project_environment.development[0].slug
  workspace_id = infisical_project.main[0].id
  folder_path  = "/"
}

resource "infisical_secret" "encryption_key" {
  count        = local.infisical_ready && length(infisical_project_environment.development) > 0 ? 1 : 0
  name         = "ENCRYPTION_KEY"
  value        = local.encryption_key_hex
  env_slug     = infisical_project_environment.development[0].slug
  workspace_id = infisical_project.main[0].id
  folder_path  = "/"
}

resource "infisical_secret" "jwt_signing_key" {
  count        = local.infisical_ready && length(infisical_project_environment.development) > 0 ? 1 : 0
  name         = "JWT_SIGNING_KEY"
  value        = local.jwt_signing_key
  env_slug     = infisical_project_environment.development[0].slug
  workspace_id = infisical_project.main[0].id
  folder_path  = "/"
}

resource "infisical_secret" "admin_password" {
  count        = local.infisical_ready && length(infisical_project_environment.development) > 0 ? 1 : 0
  name         = "ADMIN_PASSWORD"
  value        = local.admin_password
  env_slug     = infisical_project_environment.development[0].slug
  workspace_id = infisical_project.main[0].id
  folder_path  = "/"
}

