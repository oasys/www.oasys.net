# www.oasys.net

Code to build and deploy www.oasys.net.

## Initial setup

### Prerequisites

- AWS account with local permissions (for `init.sh`)
- Validated wildcard cert for `*.oasys.net` in AWS certificate manager.
- Terraform Cloud (TFC) account
- Github configured as a VCS provider for the TFC organization
- Github cli (gh) configured with access to create secrets in the repo

### Terraform

The code in the `terraform/` directory will build the required infrastructure.

First, run the `init.sh` script to:

- create an IAM user
- grant IAM user permissions to build infrastructure and deploy site to s3
- create a TFC workspace
- connect the TFC workspace with the GitHub repository
- supply environment credentials and initial terraform variables to the workspace
- add AWS credentials as GitHub secrets to the repository

Next, apply the terraform configuration to build the infrastructure.

Last, run the `update_cdn.sh` script to set the CDN distribution ID
in the hugo site config.  This is used for CDN cache invalidation at
deploy-time.

### Hugo

Install [hugo](https://gohugo.io).

```sh
brew install hugo
```

## Local Editing

```sh
hugo server -D
```

## Deploy

### Automatic

Push the changes to the `main` branch on GitHub, and the deploy workflow
will re-deploy the entire site.

### Manual

```sh
hugo
hugo deploy
```

### Update theme(s)

1. `git submodule foreach git pull upstream master`
1. `hugo server` and test via browser
1. `git submodule foreach git push`
1. `git commit -am 'update theme [for feature x]'`
