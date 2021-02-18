locals {
  tags = merge({
    CreatedBy = "Terraform"
  }, var.tags)
}
