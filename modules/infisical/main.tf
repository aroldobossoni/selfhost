# Local values for derived names
locals {
  postgres_container_name  = "${var.network_name}-postgres"
  redis_container_name     = "${var.network_name}-redis"
  infisical_container_name = var.network_name
  server_url               = var.server_url != "" ? var.server_url : "http://localhost:${var.infisical_port}"
}

# Docker network for Infisical stack
resource "docker_network" "infisical" {
  name = var.network_name

  ipam_config {
    subnet = var.network_subnet
  }
}

# PostgreSQL data volume
resource "docker_volume" "postgres_data" {
  name = var.postgres_data_volume
}

# Redis data volume
resource "docker_volume" "redis_data" {
  name = var.redis_data_volume
}

# PostgreSQL container
resource "docker_container" "postgres" {
  name  = local.postgres_container_name
  image = var.postgres_image

  memory      = var.postgres_memory_limit
  memory_swap = var.postgres_memory_limit

  env = [
    "POSTGRES_USER=${var.postgres_user}",
    "POSTGRES_PASSWORD=${var.postgres_password}",
    "POSTGRES_DB=${var.postgres_db}"
  ]

  volumes {
    volume_name    = docker_volume.postgres_data.name
    container_path = "/var/lib/postgresql/data"
  }

  networks_advanced {
    name = docker_network.infisical.name
  }

  restart = "unless-stopped"

  command = [
    "postgres",
    "-c", "shared_buffers=64MB",
    "-c", "work_mem=4MB",
    "-c", "maintenance_work_mem=32MB",
    "-c", "effective_cache_size=128MB"
  ]
}

# Redis container
resource "docker_container" "redis" {
  name  = local.redis_container_name
  image = var.redis_image

  memory      = var.redis_memory_limit
  memory_swap = var.redis_memory_limit

  command = [
    "redis-server",
    "--maxmemory", "48mb",
    "--maxmemory-policy", "allkeys-lru"
  ]

  volumes {
    volume_name    = docker_volume.redis_data.name
    container_path = "/data"
  }

  networks_advanced {
    name = docker_network.infisical.name
  }

  restart = "unless-stopped"
}

# Infisical container
resource "docker_container" "infisical" {
  name  = local.infisical_container_name
  image = var.infisical_image

  memory      = var.infisical_memory_limit
  memory_swap = var.infisical_memory_limit

  env = [
    "NODE_OPTIONS=--max-old-space-size=384",
    "DB_CONNECTION_URI=postgresql://${var.postgres_user}:${var.postgres_password}@${local.postgres_container_name}:5432/${var.postgres_db}",
    "DB_ENCRYPTION_KEY=${var.infisical_db_password}",
    "ENCRYPTION_KEY=${var.infisical_encryption_key}",
    "JWT_SIGNUP_SECRET=${var.infisical_jwt_signing_key}",
    "JWT_REFRESH_SECRET=${var.infisical_jwt_signing_key}",
    "JWT_AUTH_SECRET=${var.infisical_jwt_signing_key}",
    "REDIS_URL=redis://${local.redis_container_name}:6379",
    "SERVER_URL=${local.server_url}"
  ]

  ports {
    internal = var.infisical_port
    external = var.infisical_port
  }

  networks_advanced {
    name = docker_network.infisical.name
  }

  depends_on = [
    docker_container.postgres,
    docker_container.redis
  ]

  restart = "unless-stopped"
}
