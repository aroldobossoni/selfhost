# Infisical provider for managing secrets
# Uses Universal Auth (client_id/client_secret) for authentication
# Only functional after bootstrap creates Machine Identity credentials
provider "infisical" {
  host = var.enable_infisical ? "http://${var.docker_host_ip}:${var.infisical_port}" : "http://localhost:8080"

  auth = {
    universal = {
      client_id     = var.infisical_client_id
      client_secret = var.infisical_client_secret
    }
  }
}

