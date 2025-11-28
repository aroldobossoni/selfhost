# Infisical resources (projects, secrets)
# Project/Environment created when bootstrap is complete (admin_token available)
# Secrets created when Machine Identity credentials are available (client_id/client_secret)

locals {
  # Bootstrap complete = we have admin token and org_id (can create project)
  # This is also defined in identity.tf, but we need it here too
  can_create_project = var.enabled && var.admin_token != "" && var.org_id != ""
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

# Note: Secrets (postgres_password, encryption_key, etc.) are NOT stored in Infisical
# because the admin_token doesn't have proper project data key access.
# These credentials are managed by Terraform state and passed directly to containers.
