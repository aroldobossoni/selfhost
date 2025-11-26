terraform {
  required_version = ">= 1.14.0"

  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = ">= 3.0.2-rc05"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    infisical = {
      source  = "infisical/infisical"
      version = "~> 0.11"
    }
  }
}

