output "network_name" {
  description = "Docker network name"
  value       = docker_network.infisical.name
}

output "postgres_container_id" {
  description = "PostgreSQL container ID"
  value       = docker_container.postgres.id
}

output "redis_container_id" {
  description = "Redis container ID"
  value       = docker_container.redis.id
}

output "infisical_container_id" {
  description = "Infisical container ID"
  value       = docker_container.infisical.id
}

output "infisical_url" {
  description = "Infisical web UI URL"
  value       = local.server_url
}

output "infisical_port" {
  description = "Infisical HTTP port"
  value       = var.infisical_port
}

