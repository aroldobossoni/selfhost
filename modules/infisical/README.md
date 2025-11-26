<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.0 |
| <a name="requirement_docker"></a> [docker](#requirement\_docker) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_docker"></a> [docker](#provider\_docker) | ~> 3.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [docker_container.infisical](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/resources/container) | resource |
| [docker_container.postgres](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/resources/container) | resource |
| [docker_container.redis](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/resources/container) | resource |
| [docker_network.infisical](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/resources/network) | resource |
| [docker_volume.postgres_data](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/resources/volume) | resource |
| [docker_volume.redis_data](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs/resources/volume) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_infisical_db_password"></a> [infisical\_db\_password](#input\_infisical\_db\_password) | Infisical database password | `string` | n/a | yes |
| <a name="input_infisical_encryption_key"></a> [infisical\_encryption\_key](#input\_infisical\_encryption\_key) | Infisical encryption key (32 bytes base64) | `string` | n/a | yes |
| <a name="input_infisical_jwt_signing_key"></a> [infisical\_jwt\_signing\_key](#input\_infisical\_jwt\_signing\_key) | Infisical JWT signing key | `string` | n/a | yes |
| <a name="input_infisical_memory_limit"></a> [infisical\_memory\_limit](#input\_infisical\_memory\_limit) | Infisical container memory limit (e.g., 512m) | `string` | `"512m"` | no |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | Docker network name for Infisical stack | `string` | `"infisical"` | no |
| <a name="input_postgres_data_volume"></a> [postgres\_data\_volume](#input\_postgres\_data\_volume) | PostgreSQL data volume name | `string` | `"infisical_postgres_data"` | no |
| <a name="input_postgres_memory_limit"></a> [postgres\_memory\_limit](#input\_postgres\_memory\_limit) | PostgreSQL container memory limit (e.g., 256m) | `string` | `"256m"` | no |
| <a name="input_postgres_password"></a> [postgres\_password](#input\_postgres\_password) | PostgreSQL root password | `string` | n/a | yes |
| <a name="input_redis_data_volume"></a> [redis\_data\_volume](#input\_redis\_data\_volume) | Redis data volume name | `string` | `"infisical_redis_data"` | no |
| <a name="input_redis_memory_limit"></a> [redis\_memory\_limit](#input\_redis\_memory\_limit) | Redis container memory limit (e.g., 64m) | `string` | `"64m"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_infisical_container_id"></a> [infisical\_container\_id](#output\_infisical\_container\_id) | Infisical container ID |
| <a name="output_infisical_url"></a> [infisical\_url](#output\_infisical\_url) | Infisical web UI URL |
| <a name="output_network_name"></a> [network\_name](#output\_network\_name) | Docker network name |
| <a name="output_postgres_container_id"></a> [postgres\_container\_id](#output\_postgres\_container\_id) | PostgreSQL container ID |
| <a name="output_redis_container_id"></a> [redis\_container\_id](#output\_redis\_container\_id) | Redis container ID |
<!-- END_TF_DOCS -->

## Description

Module to deploy Infisical secrets management stack using Docker containers.

**Note:** This module inherits the Docker provider from the root configuration. Configure the Docker provider in your root `providers.tf`.

## Memory Limits

Optimized for minimal resource usage (~1GB total):

- **PostgreSQL**: 256MB (low-memory configuration)
- **Redis**: 64MB (maxmemory 48MB)
- **Infisical**: 512MB (Node.js heap limit 384MB)

## Usage

```hcl
# In providers.tf (root)
provider "docker" {
  host = "ssh://root@192.168.3.115"
}

# In main.tf (root)
module "infisical" {
  source = "./modules/infisical"

  postgres_password         = var.postgres_password
  infisical_db_password     = var.db_password
  infisical_encryption_key  = var.encryption_key
  infisical_jwt_signing_key = var.jwt_key
}
```

## Access

After deployment, access Infisical at:
- **URL**: `http://<docker-host-ip>:8080`
- **Default**: Create admin account on first access
