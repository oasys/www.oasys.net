terraform {
  required_version = ">= 1.0"

  cloud {
    organization = "oasys"
    workspaces {
      name = "www-oasys-net"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}
