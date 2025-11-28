# Generate random password for Docker LXC container
resource "random_password" "docker_lxc" {
  length  = 16
  special = false # Alpine LXC may have issues with special chars
}

locals {
  docker_lxc_password = random_password.docker_lxc.result
}
