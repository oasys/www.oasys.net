---
title: "Terraform validate list object"
date: 2021-03-08T13:53:30-05:00
tags:
  - terraform
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: |
  Using alltrue to validate complex input variables in Terraform
disableShare: false
disableHLJS: false
searchHidden: false

---

Since version 0.13, terraform has support for custom validation rules for input variables.

The example in the [documentation][docs-validation] shows how to test a single value:

```terraform
variable "image_id" {
  type        = string
  description = "The id of the machine image (AMI) to use for the server."

  validation {
    # regex(...) fails if it cannot find a match
    condition     = can(regex("^ami-", var.image_id))
    error_message = "The image_id value must be a valid AMI id, starting with \"ami-\"."
  }
}
```

But, what to do if you want to validate a more complex object, such as
`list(string)` (or other, more complicated types)?  Terraform 0.14 introduced the
`alltrue` function that makes this much easier and readable:

```terraform
variable "aliases" {
  description = "List of any aliases (CNAMEs) for the website."
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for alias in var.aliases : can(regex("^[.0-9a-z-]+$", alias))
    ])
    error_message = "Aliases must be a valid DNS name."
  }
}
```

[docs-validation]: https://www.terraform.io/docs/language/values/variables.html#custom-validation-rules
