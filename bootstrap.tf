# Bootstrap and Configure Infisical using external script
# This approach is more robust for complex API flows than pure Terraform resources

resource "null_resource" "configure_infisical" {
  count = var.enable_infisical ? 1 : 0

  triggers = {
    # Trigger only if these change, but script handles idempotency internally
    docker_host_ip = var.docker_host_ip
    infisical_port = var.infisical_port
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Use the virtual environment python if available, otherwise system python
      PYTHON_CMD="python3"
      if [ -f "${path.module}/.venv/bin/python3" ]; then
        PYTHON_CMD="${path.module}/.venv/bin/python3"
      fi
      
      $PYTHON_CMD ${path.module}/scripts/configure_infisical.py \
        "http://${var.docker_host_ip}:${var.infisical_port}" \
        "${var.infisical_admin_email}" \
        "${local.infisical_admin_password}" \
        "${var.infisical_org_name}"
    EOT
  }

  depends_on = [module.infisical]
}

# We don't need the data.http and local_file resources anymore
# as the python script handles the logic and file creation
