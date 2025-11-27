# Get Docker container IP dynamically
# If docker_host_ip is not set, obtain it from the container via SSH
locals {
  # Get container VMID
  docker_container_vmid = replace(module.docker_lxc.container_id, "proxmox/lxc/", "")
  
  # Get IP dynamically if not provided
  docker_host_ip = var.docker_host_ip != "" ? var.docker_host_ip : (
    var.enable_infisical && length(data.external.docker_ip) > 0 ? try(
      trimspace(data.external.docker_ip[0].result.ip),
      ""
    ) : ""
  )
}

# External data source to get container IP via SSH
data "external" "docker_ip" {
  count = var.enable_infisical && var.docker_host_ip == "" ? 1 : 0
  
  program = ["bash", "-c", <<-EOT
    CONTAINER_ID="${replace(module.docker_lxc.container_id, "proxmox/lxc/", "")}"
    PM_HOST="${var.pm_host}"
    
    # Wait a bit for network to be ready
    sleep 3
    
    # Get IP from container via Proxmox SSH
    IP=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@${PM_HOST} \
      "pct exec ${CONTAINER_ID} -- ip addr show eth0 2>/dev/null | grep 'inet ' | awk '{print \\\$2}' | cut -d/ -f1" 2>/dev/null || echo "")
    
    if [ -z "$IP" ]; then
      echo '{"ip":""}' >&2
      exit 1
    fi
    
    echo "{\"ip\":\"${IP}\"}"
  EOT
  ]

  depends_on = [module.docker_lxc, module.docker_lxc.null_resource.docker_install]
}

