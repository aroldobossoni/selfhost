# Infisical Bootstrap and Identity Configuration
# 
# Phase 1: Python script performs initial bootstrap (admin/org creation)
# Phase 2: Terraform creates Machine Identity using provider resources

# Bootstrap Infisical instance (creates admin user and organization)
# This is the ONLY operation that requires a script - no Terraform resource exists for it
resource "null_resource" "bootstrap_infisical" {
  count = var.enable_infisical ? 1 : 0

  triggers = {
    docker_host_ip = local.docker_host_ip
    infisical_port = var.infisical_port
  }

  provisioner "local-exec" {
    command = <<-EOT
      PYTHON_CMD="python3"
      if [ -f "${path.module}/.venv/bin/python3" ]; then
        PYTHON_CMD="${path.module}/.venv/bin/python3"
      fi
      
      $PYTHON_CMD ${path.module}/scripts/bootstrap_infisical.py \
        "http://${local.docker_host_ip}:${var.infisical_port}" \
        "${var.infisical_admin_email}" \
        "${local.infisical_admin_password}" \
        "${var.infisical_org_name}"
    EOT
  }

  depends_on = [module.infisical]
}
