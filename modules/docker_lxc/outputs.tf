output "container_id" {
  description = "ID of the created LXC container"
  value       = proxmox_lxc.docker.id
}

output "container_hostname" {
  description = "Hostname of the container"
  value       = proxmox_lxc.docker.hostname
}

output "container_ip" {
  description = "IP address of the container (from network config, may be 'dhcp')"
  value       = proxmox_lxc.docker.network[0].ip
}

output "vmid" {
  description = "VMID of the container"
  value       = proxmox_lxc.docker.vmid
}


