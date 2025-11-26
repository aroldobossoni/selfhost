# Infisical provider for managing secrets
# This provider requires a valid token to initialize
# Resources using this provider are conditional and will only be created after bootstrap
# Provider initialization will fail if token is empty, but this is expected before bootstrap
provider "infisical" {
  host          = var.enable_infisical ? "http://${var.docker_host_ip}:${var.infisical_port}" : "http://localhost:8080"
  service_token = var.infisical_token
}

