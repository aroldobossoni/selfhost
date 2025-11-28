# Infisical resources (projects, secrets)
# Project/Environment created when bootstrap is complete (admin_token available)
# Secrets created when Machine Identity credentials are available (client_id/client_secret)

locals {
  # Bootstrap complete = we have admin token and org_id (can create project)
  # This is also defined in identity.tf, but we need it here too
  can_create_project = var.enabled && var.admin_token != "" && var.org_id != ""
  
  # Infisical ready = we have Machine Identity credentials (can store secrets)
  infisical_ready = var.enabled && var.client_id != "" && var.client_secret != ""
}

# Create main project (needs bootstrap, not Machine Identity)
resource "infisical_project" "main" {
  count = local.can_create_project ? 1 : 0
  name  = var.project_name
  slug  = var.project_name
}

# Create production environment (needs project)
resource "infisical_project_environment" "production" {
  count = local.can_create_project && length(infisical_project.main) > 0 ? 1 : 0

  project_id = infisical_project.main[0].id
  name       = "production"
  slug       = "production"
}

# Store generated passwords as secrets in Infisical
# These can be created with admin_token (don't need Machine Identity)
resource "infisical_secret" "postgres_password" {
  count        = local.can_create_project && length(infisical_project_environment.production) > 0 ? 1 : 0
  name         = "POSTGRES_PASSWORD"
  value        = local.postgres_password
  env_slug     = infisical_project_environment.production[0].slug
  workspace_id = infisical_project.main[0].id
  folder_path  = "/"
}

resource "infisical_secret" "encryption_key" {
  count        = local.can_create_project && length(infisical_project_environment.production) > 0 ? 1 : 0
  name         = "ENCRYPTION_KEY"
  value        = local.encryption_key_hex
  env_slug     = infisical_project_environment.production[0].slug
  workspace_id = infisical_project.main[0].id
  folder_path  = "/"
}

resource "infisical_secret" "jwt_signing_key" {
  count        = local.can_create_project && length(infisical_project_environment.production) > 0 ? 1 : 0
  name         = "JWT_SIGNING_KEY"
  value        = local.jwt_signing_key
  env_slug     = infisical_project_environment.production[0].slug
  workspace_id = infisical_project.main[0].id
  folder_path  = "/"
}

resource "infisical_secret" "admin_password" {
  count        = local.can_create_project && length(infisical_project_environment.production) > 0 ? 1 : 0
  name         = "ADMIN_PASSWORD"
  value        = local.admin_password
  env_slug     = infisical_project_environment.production[0].slug
  workspace_id = infisical_project.main[0].id
  folder_path  = "/"
}


