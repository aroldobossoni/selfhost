output "container_id" {
  description = "ID of the created LXC container"
  value       = proxmox_lxc.docker.id
}

output "container_hostname" {
  description = "Hostname of the container"
  value       = proxmox_lxc.docker.hostname
}

output "container_ip" {
  description = "IP address of the container"
  value       = proxmox_lxc.docker.network[0].ip
}

output "portainer_url" {
  description = "Portainer URL (if installed)"
  value       = var.install_portainer ? "https://${proxmox_lxc.docker.network[0].ip}:9443" : null
}

