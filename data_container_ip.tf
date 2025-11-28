# Get container IP dynamically from Proxmox API
# This queries the container interfaces after creation to get the real DHCP IP

data "http" "container_interfaces" {
  count = var.docker_network_ip == "dhcp" ? 1 : 0

  url = "${var.pm_api_url}/nodes/${var.pm_node}/lxc/${module.docker_lxc.vmid}/interfaces"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Failed to get container interfaces from Proxmox API"
    }
  }

  request_headers = {
    Authorization = "PVEAPIToken=${var.pm_api_token_id}=${var.pm_api_token_secret}"
  }

  insecure = var.pm_tls_insecure

  depends_on = [module.docker_lxc]
}

locals {
  # Extract eth0 IP directly from API response using try() to handle all edge cases
  container_ip_from_api = try(
    split("/", [
      for iface in jsondecode(data.http.container_interfaces[0].response_body).data : iface.inet
      if iface.name == "eth0"
    ][0])[0],
    ""
  )

  # Final docker_host_ip: use API result for DHCP, or configured value for static
  docker_host_ip = var.docker_network_ip == "dhcp" ? local.container_ip_from_api : (
    var.docker_host_ip != "" ? var.docker_host_ip : split("/", var.docker_network_ip)[0]
  )
}

