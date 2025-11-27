# Download template if not exists
resource "null_resource" "download_template" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "${path.root}/scripts/download_template.sh '${var.proxmox_host}' '${var.template_storage}' '${var.ostemplate_name}'"
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
    interpreter = ["/bin/bash", "-c"]
    command     = "${path.root}/scripts/install_docker.sh '${var.proxmox_host}' '${proxmox_lxc.docker.vmid}' '${var.install_compose}'"
  }

  triggers = {
    container_id  = proxmox_lxc.docker.vmid
    script_hash   = filemd5("${path.root}/scripts/install_docker.sh")
    install_compose = var.install_compose
  }
}

