terraform {
  required_version = ">= 0.13"

  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "oasys"
    workspaces {
      name = "blog"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.7.0"
    }
  }
}
