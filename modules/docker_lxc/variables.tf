variable "target_node" {
  description = "Proxmox node name where the container will be created"
  type        = string
}

variable "hostname" {
  description = "Hostname of the LXC container"
  type        = string
}

variable "ostemplate" {
  description = "OS template for the container (e.g., local:vztmpl/debian-12-standard_12.0-1_amd64.tar.gz)"
  type        = string
}

variable "password" {
  description = "Root password for the container"
  type        = string
  sensitive   = true
}

variable "ssh_keys" {
  description = "SSH public keys to add to the container (optional)"
  type        = string
  default     = ""
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 2048
}

variable "swap" {
  description = "Swap memory in MB"
  type        = number
  default     = 512
}

variable "rootfs_storage" {
  description = "Storage for rootfs"
  type        = string
  default     = "local-lvm"
}

variable "rootfs_size" {
  description = "Rootfs size (e.g., 16G)"
  type        = string
  default     = "16G"
}

variable "network_bridge" {
  description = "Network bridge (e.g., vmbr0)"
  type        = string
  default     = "vmbr0"
}

variable "network_ip" {
  description = "IP address configuration (DHCP or CIDR notation)"
  type        = string
  default     = "dhcp"
}

variable "install_portainer" {
  description = "Install Portainer (Docker UI)"
  type        = bool
  default     = true
}

variable "install_compose" {
  description = "Install Docker Compose"
  type        = bool
  default     = true
}

variable "start_on_boot" {
  description = "Start container on boot"
  type        = bool
  default     = true
}

