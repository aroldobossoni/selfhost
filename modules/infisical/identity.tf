# Infisical Machine Identity Configuration
# Creates Machine Identity with Universal Auth for Terraform automation

locals {
  # Bootstrap completed when we have admin token and org_id
  bootstrap_complete = var.admin_token != "" && var.org_id != ""
}

# Create Machine Identity for Terraform automation
resource "infisical_identity" "terraform_controller" {
  count = var.enabled && local.bootstrap_complete ? 1 : 0

  name   = "Terraform-Controller"
  role   = "admin"
  org_id = var.org_id
}

# Attach Universal Auth to the Machine Identity
resource "infisical_identity_universal_auth" "terraform_controller" {
  count = var.enabled && local.bootstrap_complete ? 1 : 0

  identity_id = infisical_identity.terraform_controller[0].id

  client_secret_trusted_ips = [
    {
      ip_address = "0.0.0.0/0"
    }
  ]

  access_token_ttl            = 7200
  access_token_max_ttl        = 7200
  access_token_num_uses_limit = 0
}

# Create Client Secret for authentication
resource "infisical_identity_universal_auth_client_secret" "terraform_controller" {
  count = var.enabled && local.bootstrap_complete ? 1 : 0

  identity_id = infisical_identity.terraform_controller[0].id
  description = "Terraform Controller Client Secret"

  depends_on = [infisical_identity_universal_auth.terraform_controller]
}

# Store Machine Identity credentials in Infisical (after project/environment exist)
# This creates a circular dependency, so we store AFTER project is created
resource "infisical_secret" "client_id" {
  count = var.enabled && local.bootstrap_complete && length(infisical_project_environment.production) > 0 ? 1 : 0

  name         = "INFISICAL_CLIENT_ID"
  value        = infisical_identity_universal_auth_client_secret.terraform_controller[0].client_id
  env_slug     = infisical_project_environment.production[0].slug
  workspace_id = infisical_project.main[0].id
  folder_path  = "/"

  depends_on = [
    infisical_identity_universal_auth_client_secret.terraform_controller,
    infisical_project_environment.production
  ]
}

resource "infisical_secret" "client_secret" {
  count = var.enabled && local.bootstrap_complete && length(infisical_project_environment.production) > 0 ? 1 : 0

  name         = "INFISICAL_CLIENT_SECRET"
  value        = infisical_identity_universal_auth_client_secret.terraform_controller[0].client_secret
  env_slug     = infisical_project_environment.production[0].slug
  workspace_id = infisical_project.main[0].id
  folder_path  = "/"

  depends_on = [
    infisical_identity_universal_auth_client_secret.terraform_controller,
    infisical_project_environment.production
  ]
}


