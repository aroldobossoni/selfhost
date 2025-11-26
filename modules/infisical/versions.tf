terraform {
  required_version = ">= 1.14.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
      configuration_aliases = [docker]
    }
  }
}

