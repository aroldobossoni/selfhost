<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.2.0 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | 3.0.2-rc05 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_null"></a> [null](#provider\_null) | >= 3.2.0 |
| <a name="provider_proxmox"></a> [proxmox](#provider\_proxmox) | 3.0.2-rc05 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [null_resource.docker_install](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.download_template](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [proxmox_lxc.docker](https://registry.terraform.io/providers/Telmate/proxmox/3.0.2-rc05/docs/resources/lxc) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cores"></a> [cores](#input\_cores) | Number of CPU cores | `number` | `2` | no |
| <a name="input_hostname"></a> [hostname](#input\_hostname) | Hostname of the LXC container | `string` | n/a | yes |
| <a name="input_install_compose"></a> [install\_compose](#input\_install\_compose) | Install Docker Compose | `bool` | `true` | no |
| <a name="input_memory"></a> [memory](#input\_memory) | Memory in MB | `number` | `2048` | no |
| <a name="input_network_bridge"></a> [network\_bridge](#input\_network\_bridge) | Network bridge (e.g., vmbr0) | `string` | `"vmbr0"` | no |
| <a name="input_network_ip"></a> [network\_ip](#input\_network\_ip) | IP address configuration (DHCP or CIDR notation) | `string` | `"dhcp"` | no |
| <a name="input_ostemplate"></a> [ostemplate](#input\_ostemplate) | OS template for the container (e.g., local:vztmpl/alpine-3.22-default\_20250617\_amd64.tar.xz) | `string` | n/a | yes |
| <a name="input_ostemplate_name"></a> [ostemplate\_name](#input\_ostemplate\_name) | Template name to download from Proxmox repository (e.g., alpine-3.22-default\_20250617\_amd64.tar.xz) | `string` | `"alpine-3.22-default_20250617_amd64.tar.xz"` | no |
| <a name="input_password"></a> [password](#input\_password) | Root password for the container | `string` | n/a | yes |
| <a name="input_proxmox_host"></a> [proxmox\_host](#input\_proxmox\_host) | Proxmox host IP or hostname for SSH connections | `string` | n/a | yes |
| <a name="input_rootfs_size"></a> [rootfs\_size](#input\_rootfs\_size) | Rootfs size (e.g., 16G) | `string` | `"16G"` | no |
| <a name="input_rootfs_storage"></a> [rootfs\_storage](#input\_rootfs\_storage) | Storage for rootfs | `string` | `"local-zfs"` | no |
| <a name="input_start_on_boot"></a> [start\_on\_boot](#input\_start\_on\_boot) | Start container on boot | `bool` | `true` | no |
| <a name="input_swap"></a> [swap](#input\_swap) | Swap memory in MB | `number` | `512` | no |
| <a name="input_target_node"></a> [target\_node](#input\_target\_node) | Proxmox node name where the container will be created | `string` | n/a | yes |
| <a name="input_template_storage"></a> [template\_storage](#input\_template\_storage) | Storage where templates are stored | `string` | `"local"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_container_hostname"></a> [container\_hostname](#output\_container\_hostname) | Hostname of the container |
| <a name="output_container_id"></a> [container\_id](#output\_container\_id) | ID of the created LXC container |
| <a name="output_container_ip"></a> [container\_ip](#output\_container\_ip) | IP address of the container |
<!-- END_TF_DOCS -->