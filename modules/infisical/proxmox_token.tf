# Proxmox Token Management
# Creates and rotates Proxmox API tokens, storing them in Infisical

locals {
  proxmox_token_ready = var.enabled && var.client_id != "" && var.client_secret != "" && var.proxmox_host != "" && var.proxmox_ssh_user != ""
}

# Weekly rotation trigger
resource "time_rotating" "proxmox_token" {
  count = local.proxmox_token_ready ? 1 : 0

  rotation_days = 7
}

# Get Proxmox token via external data source (no files on disk)
# Query includes rotation trigger to force recalculation when rotation time changes
data "external" "proxmox_token" {
  count = local.proxmox_token_ready ? 1 : 0

  program = [
    "python3",
    "${path.module}/../../scripts/proxmox_token.py",
    var.proxmox_host,
    var.proxmox_ssh_user,
    var.proxmox_pve_user,
    var.proxmox_token_name
  ]

  query = {
    # Include rotation trigger to force recalculation when it changes
    rotation = time_rotating.proxmox_token[0].id
    # Check if rotation is needed (when rotation time has passed)
    rotate = time_rotating.proxmox_token[0].rotation_rfc3339 != time_rotating.proxmox_token[0].id ? "true" : "false"
  }

  depends_on = [time_rotating.proxmox_token]
}

# Remove Proxmox token on destroy
resource "null_resource" "proxmox_token_cleanup" {
  count = local.proxmox_token_ready ? 1 : 0

  triggers = {
    proxmox_host = var.proxmox_host
    proxmox_ssh_user = var.proxmox_ssh_user
    pve_user = var.proxmox_pve_user
    token_name = var.proxmox_token_name
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      ssh -o StrictHostKeyChecking=no "${self.triggers.proxmox_ssh_user}@${self.triggers.proxmox_host}" \
        "pveum user token delete ${self.triggers.pve_user} ${self.triggers.token_name}" 2>&1 || true
    EOT
  }

  depends_on = [data.external.proxmox_token]
}

# Store Proxmox token in Infisical
resource "infisical_secret" "proxmox_token_id" {
  count        = local.proxmox_token_ready && length(infisical_project_environment.production) > 0 && length(data.external.proxmox_token) > 0 ? 1 : 0
  name         = "PROXMOX_TOKEN_ID"
  value        = data.external.proxmox_token[0].result.token_id
  env_slug     = infisical_project_environment.production[0].slug
  workspace_id = infisical_project.main[0].id
  folder_path  = "/"

  depends_on = [data.external.proxmox_token]
}

resource "infisical_secret" "proxmox_token_secret" {
  count        = local.proxmox_token_ready && length(infisical_project_environment.production) > 0 && length(data.external.proxmox_token) > 0 ? 1 : 0
  name         = "PROXMOX_TOKEN_SECRET"
  value        = data.external.proxmox_token[0].result.token_secret
  env_slug     = infisical_project_environment.production[0].slug
  workspace_id = infisical_project.main[0].id
  folder_path  = "/"

  depends_on = [data.external.proxmox_token]
}

