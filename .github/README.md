# www.oasys.net

Code to build and deploy www.oasys.net.

## Initial setup

### Prerequisites

1. AWS account with local permissions (for `init.sh`)
2. Validated wildcard cert for `*.oasys.net` in AWS certificate manager.
3. Terraform Cloud (TFC) account
4. GitHub
5. Github configured as a VCS provider for the TFC organization

### Terraform

The code in the `terraform/` directory will build the required infrastructure.

First, run the `init.sh` script to:

- create an IAM user
- grant IAM user permissions to build infrastructure and deploy site to s3
- create a TFC workspace
- connect the TFC workspace with the GitHub repository
- supply environment credentials and initial terraform variables to the workspace

Next, apply the terraform configuration to build the infrastructure.

Last, run the `update_cdn.sh` script to set the CDN distribution ID
in the hugo site config.  This is used for CDN cache invalidation at
deploy-time.
