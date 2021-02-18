variable "domain" {
  description = "Domain of website"
  type        = string
}

variable "deploy_arn" {
  description = "ARN of AWS user who will deploy objects to bucket"
  type        = string
}

variable "tags" {
  description = "Common tags for created resources"
  type        = map(any)
  default     = {}
}
