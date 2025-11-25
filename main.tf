module "docker_lxc" {
  source = "./modules/docker_lxc"

  target_node      = var.pm_node
  hostname         = var.docker_hostname
  ostemplate       = var.docker_ostemplate
  password         = var.docker_password
  cores            = var.docker_cores
  memory           = var.docker_memory
  swap             = var.docker_swap
  rootfs_storage   = var.docker_rootfs_storage
  rootfs_size      = var.docker_rootfs_size
  network_bridge   = var.docker_network_bridge
  network_ip       = var.docker_network_ip
  install_portainer = var.docker_install_portainer
  install_compose   = var.docker_install_compose
  start_on_boot     = var.docker_start_on_boot
}

