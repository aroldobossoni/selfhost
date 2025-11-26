variable "pm_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://192.168.3.2:8006/api2/json"
}

variable "pm_api_token_id" {
  description = "Proxmox API Token ID"
  type        = string
  sensitive   = true
  default     = "terraform-prov@pve!terraform-token"
}

variable "pm_api_token_secret" {
  description = "Proxmox API Token Secret"
  type        = string
  sensitive   = true
  default     = "your-token-secret-here"
}

variable "pm_tls_insecure" {
  description = "Allow insecure TLS connections to Proxmox API"
  type        = bool
  default     = true
}

variable "pm_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve"
}

variable "pm_host" {
  description = "Proxmox host IP or hostname for SSH connections"
  type        = string
  default     = "192.168.3.2"
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = var.pm_tls_insecure
}

