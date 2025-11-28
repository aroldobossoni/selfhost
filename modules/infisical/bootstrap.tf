# Infisical Bootstrap
# 
# This is the ONLY operation that requires a script - no Terraform resource exists for it.
# The bootstrap creates admin user and organization via API.

resource "null_resource" "bootstrap" {
  count = var.enabled && var.admin_token == "" ? 1 : 0

  triggers = {
    server_url  = var.server_url
    admin_email = var.admin_email
  }

  provisioner "local-exec" {
    command = <<-EOT
      PYTHON_CMD="python3"
      if [ -f "${path.root}/.venv/bin/python3" ]; then
        PYTHON_CMD="${path.root}/.venv/bin/python3"
      fi
      
      $PYTHON_CMD ${path.root}/scripts/bootstrap_infisical.py \
        "${var.server_url}" \
        "${var.admin_email}" \
        "${local.admin_password}" \
        "${var.org_name}"
    EOT
  }

  depends_on = [
    docker_container.infisical
  ]
}

