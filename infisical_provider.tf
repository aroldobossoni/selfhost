# Infisical provider for managing secrets
# 
# Authentication modes:
# - Token auth: Used after bootstrap with admin token (for creating identity)
# - Universal Auth: Used after identity is created (for normal operations)
#
# The provider uses token auth by default. After infisical_token.auto.tfvars
# is created with client_id/secret, switch to Universal Auth by updating this file.
provider "infisical" {
  host = var.enable_infisical ? "http://${var.docker_host_ip}:${var.infisical_port}" : "http://localhost:8080"

  # Token auth - used for initial identity creation
  # After credentials are generated, this can be switched to universal auth
  auth = {
    token = coalesce(var.infisical_admin_token, var.infisical_token, "placeholder")
  }
}

