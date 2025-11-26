variable "pm_api_url" {
  description = "Proxmox API URL (e.g., https://192.168.3.2:8006/api2/json)"
  type        = string
}

variable "pm_api_token_id" {
  description = "Proxmox API Token ID (e.g., user@pam!token-name)"
  type        = string
  sensitive   = true
}

variable "pm_api_token_secret" {
  description = "Proxmox API Token Secret"
  type        = string
  sensitive   = true
}

variable "pm_tls_insecure" {
  description = "Allow insecure TLS connections to Proxmox API"
  type        = bool
  default     = true
}

variable "pm_node" {
  description = "Proxmox node name"
  type        = string
}

variable "pm_host" {
  description = "Proxmox host IP or hostname for SSH connections"
  type        = string
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = var.pm_tls_insecure
}

# Docker provider for Infisical module
# Only used when enable_infisical = true
provider "docker" {
  alias = "infisical"
  host  = "ssh://root@${var.docker_host_ip}"
}

