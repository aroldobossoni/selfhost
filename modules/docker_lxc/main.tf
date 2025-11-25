resource "proxmox_lxc" "docker" {
  target_node  = var.target_node
  hostname     = var.hostname
  ostemplate   = var.ostemplate
  password     = var.password
  unprivileged = false
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

# Install Docker using helper script via pct exec on Proxmox host
resource "null_resource" "docker_install" {
  depends_on = [proxmox_lxc.docker]

  provisioner "local-exec" {
    command = <<-EOT
      sleep 15
      ssh -o StrictHostKeyChecking=no root@${var.target_node} "pct exec ${proxmox_lxc.docker.id} -- bash -c 'export DEBIAN_FRONTEND=noninteractive && echo -e \"y\\n${var.install_compose ? "y" : "n"}\\n${var.install_portainer ? "y" : "n"}\" | bash -c \"\$(wget -qLO - https://github.com/tteck/Proxmox/raw/main/ct/docker.sh)\"'"
    EOT
  }

  triggers = {
    container_id = proxmox_lxc.docker.id
  }
}

