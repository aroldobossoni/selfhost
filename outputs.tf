output "docker_container_id" {
  description = "ID of the Docker LXC container"
  value       = module.docker_lxc.container_id
}

output "docker_container_hostname" {
  description = "Hostname of the Docker container"
  value       = module.docker_lxc.container_hostname
}

output "docker_container_ip" {
  description = "IP address of the Docker container"
  value       = module.docker_lxc.container_ip
}

output "infisical_url" {
  description = "Infisical web UI URL"
  value       = var.enable_infisical ? module.infisical[0].infisical_url : null
}

output "infisical_container_id" {
  description = "Infisical container ID"
  value       = var.enable_infisical ? module.infisical[0].infisical_container_id : null
}


