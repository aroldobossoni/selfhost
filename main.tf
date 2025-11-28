module "docker_lxc" {
  source = "./modules/docker_lxc"

  target_node       = var.pm_node
  proxmox_host      = var.pm_host
  proxmox_ssh_user  = var.proxmox_ssh_user
  hostname          = var.docker_hostname
  ostemplate        = var.docker_ostemplate
  ostemplate_name   = var.docker_ostemplate_name
  template_storage  = var.docker_template_storage
  password          = local.docker_lxc_password
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

  providers = {
    docker = docker.infisical
  }

  enabled                   = var.enable_infisical
  infisical_port            = var.infisical_port
  server_url                = "http://${local.docker_host_ip}:${var.infisical_port}"
  postgres_password         = local.postgres_password
  infisical_db_password     = local.postgres_password
  infisical_encryption_key  = local.encryption_key_hex
  infisical_jwt_signing_key = local.jwt_signing_key

  depends_on = [module.docker_lxc]
}

