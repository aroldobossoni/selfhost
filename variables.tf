variable "docker_hostname" {
  description = "Hostname for the Docker LXC container"
  type        = string
  default     = "docker-lxc"
}

variable "docker_ostemplate" {
  description = "OS template for Docker container"
  type        = string
  default     = "local:vztmpl/alpine-3.22-default_20250617_amd64.tar.xz"
}

variable "docker_ostemplate_name" {
  description = "Template name to download from Proxmox repository"
  type        = string
  default     = "alpine-3.22-default_20250617_amd64.tar.xz"
}

variable "docker_template_storage" {
  description = "Storage where templates are stored"
  type        = string
  default     = "local"
}

variable "docker_password" {
  description = "Root password for Docker container (minimum 5 characters)"
  type        = string
  sensitive   = true
  default     = "95429"
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
  default     = "local-zfs"
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

