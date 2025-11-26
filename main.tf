module "docker_lxc" {
  source = "./modules/docker_lxc"

  target_node       = var.pm_node
  proxmox_host      = var.pm_host
  hostname          = var.docker_hostname
  ostemplate        = var.docker_ostemplate
  ostemplate_name   = var.docker_ostemplate_name
  template_storage  = var.docker_template_storage
  password          = var.docker_password
  cores             = var.docker_cores
  memory            = var.docker_memory
  swap              = var.docker_swap
  rootfs_storage    = var.docker_rootfs_storage
  rootfs_size       = var.docker_rootfs_size
  network_bridge    = var.docker_network_bridge
  network_ip        = var.docker_network_ip
  install_compose   = var.docker_install_compose
  start_on_boot     = var.docker_start_on_boot
}

module "infisical" {
  source = "./modules/infisical"
  count  = var.enable_infisical ? 1 : 0

  docker_host               = "ssh://root@${var.docker_host_ip}"
  postgres_password         = var.infisical_postgres_password
  infisical_db_password     = var.infisical_db_password
  infisical_encryption_key  = var.infisical_encryption_key
  infisical_jwt_signing_key = var.infisical_jwt_signing_key

  depends_on = [module.docker_lxc]
}

