# Download template if not exists
resource "null_resource" "download_template" {
  provisioner "local-exec" {
    command = <<-EOT
      PYTHON_CMD="python3"
      if [ -f "${path.root}/.venv/bin/python3" ]; then
        PYTHON_CMD="${path.root}/.venv/bin/python3"
      fi
      
      $PYTHON_CMD ${path.root}/scripts/proxmox_utils.py download_template \
        "${var.proxmox_host}" \
        "${var.proxmox_ssh_user}" \
        "${var.template_storage}" \
        "${var.ostemplate_name}"
    EOT
  }

  triggers = {
    template_name = var.ostemplate_name
  }
}

resource "proxmox_lxc" "docker" {
  depends_on = [null_resource.download_template]

  target_node  = var.target_node
  hostname     = var.hostname
  ostemplate   = var.ostemplate
  password     = var.password
  unprivileged = true
  cores        = var.cores
  memory       = var.memory
  swap         = var.swap
  start        = true
  onboot       = var.start_on_boot

  rootfs {
    storage = var.rootfs_storage
    size    = var.rootfs_size
  }

  network {
    name   = "eth0"
    bridge = var.network_bridge
    ip     = var.network_ip
  }

  features {
    nesting = true
  }
}

# Install Docker and SSH on Alpine via pct exec
resource "null_resource" "docker_install" {
  depends_on = [proxmox_lxc.docker]

  provisioner "local-exec" {
    command = <<-EOT
      PYTHON_CMD="python3"
      if [ -f "${path.root}/.venv/bin/python3" ]; then
        PYTHON_CMD="${path.root}/.venv/bin/python3"
      fi
      
      $PYTHON_CMD ${path.root}/scripts/proxmox_utils.py install_docker \
        "${var.proxmox_host}" \
        "${var.proxmox_ssh_user}" \
        "${proxmox_lxc.docker.vmid}" \
        "${var.install_compose}"
    EOT
  }

  triggers = {
    container_id  = proxmox_lxc.docker.vmid
    script_hash   = filemd5("${path.root}/scripts/proxmox_utils.py")
    install_compose = var.install_compose
  }
}

