# =============================================================================
# Docker LXC Outputs
# =============================================================================

output "docker_container_id" {
  description = "ID of the Docker LXC container"
  value       = module.docker_lxc.container_id
}

output "docker_container_hostname" {
  description = "Hostname of the Docker container"
  value       = module.docker_lxc.container_hostname
}

output "docker_container_ip" {
  description = "IP address of the Docker container (from Proxmox API)"
  value       = local.docker_host_ip
}

output "docker_lxc_password" {
  description = "Auto-generated password for Docker LXC container"
  value       = local.docker_lxc_password
  sensitive   = true
}

# =============================================================================
# Infisical Outputs
# =============================================================================

output "infisical_url" {
  description = "Infisical web UI URL"
  value       = module.infisical.infisical_url
}

output "infisical_container_id" {
  description = "Infisical container ID"
  value       = module.infisical.infisical_container_id
}

output "infisical_bootstrap_complete" {
  description = "Whether Infisical bootstrap is complete"
  value       = module.infisical.bootstrap_complete
  sensitive   = true
}

output "infisical_admin_password" {
  description = "Infisical admin password"
  value       = module.infisical.admin_password
  sensitive   = true
}

output "infisical_client_id" {
  description = "Infisical Machine Identity Client ID"
  value       = module.infisical.client_id
  sensitive   = true
}

output "infisical_client_secret" {
  description = "Infisical Machine Identity Client Secret"
  value       = module.infisical.client_secret
  sensitive   = true
}

output "infisical_project_id" {
  description = "Infisical project ID"
  value       = module.infisical.project_id
}
