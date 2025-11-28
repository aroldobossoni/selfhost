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

# Create/rotate Proxmox token via SSH
resource "null_resource" "proxmox_token" {
  count = local.proxmox_token_ready ? 1 : 0

  triggers = {
    # Rotation trigger: when time_rotating changes, token is rotated
    rotation = time_rotating.proxmox_token[0].id
    proxmox_host = var.proxmox_host
    proxmox_ssh_user = var.proxmox_ssh_user
    pve_user = var.proxmox_pve_user
    token_name = var.proxmox_token_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      PYTHON_CMD=$(which python3 || which python)
      if [ -z "$PYTHON_CMD" ]; then
        echo "ERROR: python3 not found"
        exit 1
      fi

      # Try to create token first (if doesn't exist)
      # If it exists, rotate it
      $PYTHON_CMD ${path.module}/../../scripts/proxmox_token.py \
        "${var.proxmox_host}" \
        "${var.proxmox_ssh_user}" \
        "${var.proxmox_pve_user}" \
        "${var.proxmox_token_name}" > /tmp/proxmox_token.json 2>&1 || \
      $PYTHON_CMD ${path.module}/../../scripts/proxmox_token.py \
        "${var.proxmox_host}" \
        "${var.proxmox_ssh_user}" \
        "${var.proxmox_pve_user}" \
        "${var.proxmox_token_name}" \
        --rotate > /tmp/proxmox_token.json 2>&1

      # Extract token values using jq if available, otherwise grep
      if command -v jq >/dev/null 2>&1; then
        TOKEN_ID=$(cat /tmp/proxmox_token.json | jq -r '.token_id // empty')
        TOKEN_SECRET=$(cat /tmp/proxmox_token.json | jq -r '.token_secret // empty')
      else
        TOKEN_ID=$(cat /tmp/proxmox_token.json | grep -o '"token_id": "[^"]*"' | cut -d'"' -f4)
        TOKEN_SECRET=$(cat /tmp/proxmox_token.json | grep -o '"token_secret": "[^"]*"' | cut -d'"' -f4)
      fi

      if [ -z "$TOKEN_ID" ] || [ -z "$TOKEN_SECRET" ] || [ "$TOKEN_SECRET" = "SECRET_NOT_AVAILABLE" ]; then
        echo "ERROR: Failed to extract token from script output"
        cat /tmp/proxmox_token.json
        exit 1
      fi

      # Save to file for Terraform to read
      echo "$TOKEN_ID" > /tmp/proxmox_token_id.txt
      echo "$TOKEN_SECRET" > /tmp/proxmox_token_secret.txt
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      # Remove Proxmox token on destroy
      # self.triggers is available in destroy-time provisioners
      ssh -o StrictHostKeyChecking=no "${self.triggers.proxmox_ssh_user}@${self.triggers.proxmox_host}" \
        "pveum user token delete ${self.triggers.pve_user} ${self.triggers.token_name}" 2>&1 || true
      
      echo "Proxmox token ${self.triggers.pve_user}!${self.triggers.token_name} removed (if existed)"
    EOT
  }

  depends_on = [
    infisical_project.main,
    infisical_project_environment.production
  ]
}

# Read token values from files created by null_resource
data "local_file" "proxmox_token_id" {
  count    = local.proxmox_token_ready ? 1 : 0
  filename = "/tmp/proxmox_token_id.txt"
  depends_on = [null_resource.proxmox_token]
}

data "local_file" "proxmox_token_secret" {
  count    = local.proxmox_token_ready ? 1 : 0
  filename = "/tmp/proxmox_token_secret.txt"
  depends_on = [null_resource.proxmox_token]
}

# Store Proxmox token in Infisical
resource "infisical_secret" "proxmox_token_id" {
  count        = local.proxmox_token_ready && length(infisical_project_environment.production) > 0 ? 1 : 0
  name         = "PROXMOX_TOKEN_ID"
  value        = trimspace(data.local_file.proxmox_token_id[0].content)
  env_slug     = infisical_project_environment.production[0].slug
  workspace_id = infisical_project.main[0].id
  folder_path  = "/"

  depends_on = [null_resource.proxmox_token]
}

resource "infisical_secret" "proxmox_token_secret" {
  count        = local.proxmox_token_ready && length(infisical_project_environment.production) > 0 ? 1 : 0
  name         = "PROXMOX_TOKEN_SECRET"
  value        = trimspace(data.local_file.proxmox_token_secret[0].content)
  env_slug     = infisical_project_environment.production[0].slug
  workspace_id = infisical_project.main[0].id
  folder_path  = "/"

  depends_on = [null_resource.proxmox_token]
}

