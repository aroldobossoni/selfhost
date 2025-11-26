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
  description = "Docker network name for Infisical stack"
  type        = string
  default     = "infisical"
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

