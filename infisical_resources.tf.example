# Infisical resources managed via Terraform provider

# Create main project
resource "infisical_project" "selfhost" {
  count = var.enable_infisical && local.final_infisical_token != "" ? 1 : 0
  name  = var.infisical_project_name
  slug  = var.infisical_project_name
}

# Store generated passwords as secrets in Infisical
resource "infisical_secret" "postgres_password" {
  count        = var.enable_infisical && local.final_infisical_token != "" && length(infisical_project.selfhost) > 0 ? 1 : 0
  name         = "POSTGRES_PASSWORD"
  value        = local.postgres_password
  env_slug     = "development"
  workspace_id = infisical_project.selfhost[0].id
  folder_path  = "/"
}

resource "infisical_secret" "encryption_key" {
  count        = var.enable_infisical && local.final_infisical_token != "" && length(infisical_project.selfhost) > 0 ? 1 : 0
  name         = "ENCRYPTION_KEY"
  value        = local.encryption_key_hex
  env_slug     = "development"
  workspace_id = infisical_project.selfhost[0].id
  folder_path  = "/"
}

resource "infisical_secret" "jwt_signing_key" {
  count        = var.enable_infisical && local.final_infisical_token != "" && length(infisical_project.selfhost) > 0 ? 1 : 0
  name         = "JWT_SIGNING_KEY"
  value        = local.jwt_signing_key
  env_slug     = "development"
  workspace_id = infisical_project.selfhost[0].id
  folder_path  = "/"
}

resource "infisical_secret" "admin_password" {
  count        = var.enable_infisical && local.final_infisical_token != "" && length(infisical_project.selfhost) > 0 ? 1 : 0
  name         = "ADMIN_PASSWORD"
  value        = local.infisical_admin_password
  env_slug     = "development"
  workspace_id = infisical_project.selfhost[0].id
  folder_path  = "/"
}

