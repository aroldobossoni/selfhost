variable "docker_hostname" {
  description = "Hostname for the Docker LXC container"
  type        = string
  default     = "docker-lxc"
}

variable "docker_ostemplate" {
  description = "OS template for Docker container"
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.0-1_amd64.tar.gz"
}

variable "docker_password" {
  description = "Root password for Docker container"
  type        = string
  sensitive   = true
}

variable "docker_cores" {
  description = "Number of CPU cores for Docker container"
  type        = number
  default     = 2
}

variable "docker_memory" {
  description = "Memory in MB for Docker container"
  type        = number
  default     = 2048
}

variable "docker_swap" {
  description = "Swap memory in MB for Docker container"
  type        = number
  default     = 512
}

variable "docker_rootfs_storage" {
  description = "Storage for Docker container rootfs"
  type        = string
  default     = "local-lvm"
}

variable "docker_rootfs_size" {
  description = "Rootfs size for Docker container (e.g., 16G)"
  type        = string
  default     = "16G"
}

variable "docker_network_bridge" {
  description = "Network bridge for Docker container"
  type        = string
  default     = "vmbr0"
}

variable "docker_network_ip" {
  description = "IP address configuration for Docker container (DHCP or CIDR)"
  type        = string
  default     = "dhcp"
}

variable "docker_install_portainer" {
  description = "Install Portainer (Docker UI)"
  type        = bool
  default     = true
}

variable "docker_install_compose" {
  description = "Install Docker Compose"
  type        = bool
  default     = true
}

variable "docker_start_on_boot" {
  description = "Start Docker container on boot"
  type        = bool
  default     = true
}

