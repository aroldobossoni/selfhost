module "docker_lxc" {
  source = "./modules/docker_lxc"

  target_node      = var.pm_node
  proxmox_host     = var.pm_host
  proxmox_ssh_user = var.proxmox_ssh_user
  hostname         = var.docker_hostname
  ostemplate       = var.docker_ostemplate
  ostemplate_name  = var.docker_ostemplate_name
  template_storage = var.docker_template_storage
  password         = local.docker_lxc_password
  cores            = var.docker_cores
  memory           = var.docker_memory
  swap             = var.docker_swap
  rootfs_storage   = var.docker_rootfs_storage
  rootfs_size      = var.docker_rootfs_size
  network_bridge   = var.docker_network_bridge
  network_ip       = var.docker_network_ip
  install_compose  = var.docker_install_compose
  start_on_boot    = var.docker_start_on_boot
}

module "infisical" {
  source = "./modules/infisical"

  providers = {
    docker    = docker.infisical
    infisical = infisical
  }

  enabled      = var.enable_infisical
  server_url   = "http://${local.docker_host_ip}:${var.infisical_port}"
  admin_email  = var.infisical_admin_email
  org_name     = var.infisical_org_name
  project_name = var.infisical_project_name

  # Bootstrap outputs (from .auto.tfvars)
  admin_token = var.infisical_admin_token
  org_id      = var.infisical_org_id

  # Machine Identity credentials (from .auto.tfvars)
  client_id     = var.infisical_client_id
  client_secret = var.infisical_client_secret

  # Proxmox token management
  proxmox_host      = var.pm_host
  proxmox_ssh_user  = var.proxmox_ssh_user
  proxmox_pve_user  = var.proxmox_pve_user
  proxmox_token_name = var.proxmox_token_name

  depends_on = [module.docker_lxc]
}
