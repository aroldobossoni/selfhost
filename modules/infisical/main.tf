# Docker network for Infisical stack
resource "docker_network" "infisical" {
  name = var.network_name

  ipam_config {
    subnet = "172.20.0.0/16"
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
  name  = "infisical-postgres"
  image = "postgres:15-alpine"

  memory      = var.postgres_memory_limit
  memory_swap = var.postgres_memory_limit

  env = [
    "POSTGRES_USER=postgres",
    "POSTGRES_PASSWORD=${var.postgres_password}",
    "POSTGRES_DB=infisical"
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
  name  = "infisical-redis"
  image = "redis:7-alpine"

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
  name  = "infisical"
  image = "infisical/infisical:latest"

  memory      = var.infisical_memory_limit
  memory_swap = var.infisical_memory_limit

  env = [
    "NODE_OPTIONS=--max-old-space-size=384",
    "DB_CONNECTION_URI=postgresql://postgres:${var.postgres_password}@infisical-postgres:5432/infisical",
    "DB_ENCRYPTION_KEY=${var.infisical_db_password}",
    "ENCRYPTION_KEY=${var.infisical_encryption_key}",
    "JWT_SIGNUP_SECRET=${var.infisical_jwt_signing_key}",
    "JWT_REFRESH_SECRET=${var.infisical_jwt_signing_key}",
    "JWT_AUTH_SECRET=${var.infisical_jwt_signing_key}",
    "REDIS_URL=redis://infisical-redis:6379",
    "SERVER_URL=http://localhost:8080"
  ]

  ports {
    internal = 8080
    external = 8080
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

