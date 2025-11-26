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
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Enable/disable all resources in this module | `bool` | `true` | no |
| <a name="input_infisical_db_password"></a> [infisical\_db\_password](#input\_infisical\_db\_password) | Infisical database password | `string` | `""` | no |
| <a name="input_infisical_encryption_key"></a> [infisical\_encryption\_key](#input\_infisical\_encryption\_key) | Infisical encryption key (32 bytes base64) | `string` | `""` | no |
| <a name="input_infisical_image"></a> [infisical\_image](#input\_infisical\_image) | Infisical Docker image | `string` | `"infisical/infisical:latest"` | no |
| <a name="input_infisical_jwt_signing_key"></a> [infisical\_jwt\_signing\_key](#input\_infisical\_jwt\_signing\_key) | Infisical JWT signing key | `string` | `""` | no |
| <a name="input_infisical_port"></a> [infisical\_port](#input\_infisical\_port) | Infisical HTTP port | `number` | `8080` | no |
| <a name="input_network_name"></a> [network\_name](#input\_network\_name) | Docker network name for Infisical stack (also used as container name prefix) | `string` | `"infisical"` | no |
| <a name="input_network_subnet"></a> [network\_subnet](#input\_network\_subnet) | Docker network subnet CIDR | `string` | `"172.20.0.0/16"` | no |
| <a name="input_postgres_data_volume"></a> [postgres\_data\_volume](#input\_postgres\_data\_volume) | PostgreSQL data volume name | `string` | `"infisical_postgres_data"` | no |
| <a name="input_postgres_db"></a> [postgres\_db](#input\_postgres\_db) | PostgreSQL database name | `string` | `"infisical"` | no |
| <a name="input_postgres_image"></a> [postgres\_image](#input\_postgres\_image) | PostgreSQL Docker image | `string` | `"postgres:15-alpine"` | no |
| <a name="input_postgres_password"></a> [postgres\_password](#input\_postgres\_password) | PostgreSQL root password | `string` | `""` | no |
| <a name="input_postgres_user"></a> [postgres\_user](#input\_postgres\_user) | PostgreSQL username | `string` | `"postgres"` | no |
| <a name="input_redis_data_volume"></a> [redis\_data\_volume](#input\_redis\_data\_volume) | Redis data volume name | `string` | `"infisical_redis_data"` | no |
| <a name="input_redis_image"></a> [redis\_image](#input\_redis\_image) | Redis Docker image | `string` | `"redis:7-alpine"` | no |
| <a name="input_server_url"></a> [server\_url](#input\_server\_url) | Infisical server URL (for CORS and redirects) | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_infisical_container_id"></a> [infisical\_container\_id](#output\_infisical\_container\_id) | Infisical container ID |
| <a name="output_infisical_port"></a> [infisical\_port](#output\_infisical\_port) | Infisical HTTP port |
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
