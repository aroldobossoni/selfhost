# Infisical provider for managing secrets
# 
# Uses Universal Auth (client_id/client_secret) when available,
# otherwise uses admin token for initial identity creation.
#
# After bootstrap creates infisical_token.auto.tfvars with credentials,
# subsequent runs will use Universal Auth automatically.

provider "infisical" {
  host = var.enable_infisical ? "http://${var.docker_host_ip}:${var.infisical_port}" : "http://localhost:8080"

  # Dynamic auth based on available credentials
  # Universal Auth is used when client_id/secret are set (from infisical_token.auto.tfvars)
  # Token Auth is used during bootstrap phase (from infisical_bootstrap.auto.tfvars)
  auth = {
    universal = var.infisical_client_id != "" ? {
      client_id     = var.infisical_client_id
      client_secret = var.infisical_client_secret
    } : null

    token = var.infisical_client_id == "" ? coalesce(var.infisical_admin_token, "not-yet-bootstrapped") : null
  }
}
