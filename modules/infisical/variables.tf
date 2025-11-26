variable "docker_host" {
  description = "Docker host connection string (e.g., ssh://root@192.168.3.115)"
  type        = string
}

variable "postgres_password" {
  description = "PostgreSQL root password"
  type        = string
  sensitive   = true
}

variable "infisical_db_password" {
  description = "Infisical database password"
  type        = string
  sensitive   = true
}

variable "infisical_encryption_key" {
  description = "Infisical encryption key (32 bytes base64)"
  type        = string
  sensitive   = true
}

variable "infisical_jwt_signing_key" {
  description = "Infisical JWT signing key"
  type        = string
  sensitive   = true
}

variable "postgres_memory_limit" {
  description = "PostgreSQL container memory limit (e.g., 256m)"
  type        = string
  default     = "256m"
}

variable "redis_memory_limit" {
  description = "Redis container memory limit (e.g., 64m)"
  type        = string
  default     = "64m"
}

variable "infisical_memory_limit" {
  description = "Infisical container memory limit (e.g., 512m)"
  type        = string
  default     = "512m"
}

variable "network_name" {
  description = "Docker network name for Infisical stack (also used as container name prefix)"
  type        = string
  default     = "infisical"
}

variable "network_subnet" {
  description = "Docker network subnet CIDR"
  type        = string
  default     = "172.20.0.0/16"
}

variable "postgres_data_volume" {
  description = "PostgreSQL data volume name"
  type        = string
  default     = "infisical_postgres_data"
}

variable "redis_data_volume" {
  description = "Redis data volume name"
  type        = string
  default     = "infisical_redis_data"
}

variable "postgres_image" {
  description = "PostgreSQL Docker image"
  type        = string
  default     = "postgres:15-alpine"
}

variable "redis_image" {
  description = "Redis Docker image"
  type        = string
  default     = "redis:7-alpine"
}

variable "infisical_image" {
  description = "Infisical Docker image"
  type        = string
  default     = "infisical/infisical:latest"
}

variable "postgres_user" {
  description = "PostgreSQL username"
  type        = string
  default     = "postgres"
}

variable "postgres_db" {
  description = "PostgreSQL database name"
  type        = string
  default     = "infisical"
}

variable "infisical_port" {
  description = "Infisical HTTP port"
  type        = number
  default     = 8080
}

variable "server_url" {
  description = "Infisical server URL (for CORS and redirects)"
  type        = string
  default     = ""
}
