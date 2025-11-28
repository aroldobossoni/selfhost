# Proxmox provider
provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = var.pm_tls_insecure
}

# Docker provider for Infisical module
provider "docker" {
  alias = "infisical"
  host  = "ssh://${var.docker_ssh_user}@${local.docker_host_ip}"
}

# Infisical provider
# Uses Universal Auth when available, otherwise uses admin token
provider "infisical" {
  host = "http://${local.docker_host_ip}:${var.infisical_port}"

  auth = {
    universal = var.infisical_client_id != "" ? {
      client_id     = var.infisical_client_id
      client_secret = var.infisical_client_secret
    } : null

    token = var.infisical_client_id == "" ? coalesce(var.infisical_admin_token, "not-yet-bootstrapped") : null
  }
}
