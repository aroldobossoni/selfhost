output "network_name" {
  description = "Docker network name"
  value       = var.enabled ? docker_network.infisical[0].name : null
}

output "postgres_container_id" {
  description = "PostgreSQL container ID"
  value       = var.enabled ? docker_container.postgres[0].id : null
}

output "redis_container_id" {
  description = "Redis container ID"
  value       = var.enabled ? docker_container.redis[0].id : null
}

output "infisical_container_id" {
  description = "Infisical container ID"
  value       = var.enabled ? docker_container.infisical[0].id : null
}

output "infisical_url" {
  description = "Infisical web UI URL"
  value       = var.enabled ? local.server_url : null
}

output "infisical_port" {
  description = "Infisical HTTP port"
  value       = var.infisical_port
}
