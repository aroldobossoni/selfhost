# Proxmox Token Management
# Token is created/rotated by deploy.py before Terraform runs
# This file only handles cleanup on destroy and storing in Infisical

locals {
  # Token cleanup only needs SSH access to Proxmox
  proxmox_ssh_ready = var.enabled && var.proxmox_host != "" && var.proxmox_ssh_user != ""
}

# Remove Proxmox token on destroy
resource "null_resource" "proxmox_token_cleanup" {
  count = local.proxmox_ssh_ready ? 1 : 0

  triggers = {
    proxmox_host     = var.proxmox_host
    proxmox_ssh_user = var.proxmox_ssh_user
    pve_user         = var.proxmox_pve_user
    token_name       = var.proxmox_token_name
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=10 \
        "${self.triggers.proxmox_ssh_user}@${self.triggers.proxmox_host}" \
        "pveum user token delete ${self.triggers.pve_user} ${self.triggers.token_name}" 2>&1 || true
    EOT
  }
}
