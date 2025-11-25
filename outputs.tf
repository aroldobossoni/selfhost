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

output "portainer_url" {
  description = "Portainer URL (if installed)"
  value       = module.docker_lxc.portainer_url
}

