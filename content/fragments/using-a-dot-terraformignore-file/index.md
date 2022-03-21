---
title: "Using a .terraformignore file"
date: 2022-03-21
tags:
  - terraform
  - terraform cloud
  - git
  - hugo
categories:
  - networking
showToc: false
TocOpen: false
draft: false
hidemeta: false
comments: false
description: |
  Speed up Terraform Cloud runs on repositories with many non-terraform files
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "cover.jpg"
    alt: "Crowd"
    caption: "[Crowd](https://pixabay.com/photos/lego-toys-figurines-crowd-many-1044891/) by [eak_kkk](https://pixabay.com/users/eak_kkk-907811/) licensed under [CC0](https://creativecommons.org/publicdomain/zero/1.0/legalcode)"
    relative: true

---

By default, a [Terraform Cloud][tfc] remote run will copy the entire
source repository to the TFC runner before it runs the plan.  If there
are lots of files in the repository that aren't needed by Terraform,
this can take a long time.  Using the `.terraformignore` file can
significantly reduce the time for TFC to prepare a remote plan.

A common pattern is to have a `terraform/` subdirectory in a repository
to deploy the infrastructure that supports the application/service/code
in the repository itself.  For the purposes of TFC, only that subdirectory
is needed by the runner.

As a simple example, I'll use the [repository for this blog][blog].
It uses the [Hugo][hugo] static site generator to generate content
from a bunch of markdown files.  Alongside the content, there is a
`terraform/` directory to create/manage an AWS [S3][s3] bucket, and
[CloudFront][cloudfront] distribution.

```text
www.oasys.net/
├── archetypes
├── assets
│   ├── css
│   └── scss
├── content
│   ├── fragments
│   └── posts
├── data
├── layouts
│   ├── _default
│   ├── partials
│   ├── resume
│   ├── shortcodes
│   └── static
├── public
├── resources
│   └── _gen
├── static
├── terraform
└── themes
    └── PaperMod
```

In this small repo there are hundreds of directories and thousands of files
that are needlessly copied to the runner, slowing down execution:

```bash
moonstone:~/www.oasys.net/terraform/(main=)[www-oasys-net]$ time terraform plan
Running plan in Terraform Cloud. Output will stream here. Pressing Ctrl-C
will stop streaming the logs, but will not stop the plan running remotely.

Preparing the remote plan...

The remote workspace is configured to work with configuration at
terraform relative to the target repository.

Terraform will upload the contents of the following directory,
excluding files or directories as defined by a .terraformignore file
at /Users/jlavoie/www.oasys.net/.terraformignore (if it is present),
in order to capture the filesystem context the remote workspace expects:
    /Users/jlavoie/www.oasys.net

To view this run in a browser, visit:
https://app.terraform.io/app/oasys/www-oasys-net/runs/run-gySZB1FwgNznF8Hd

Waiting for the plan to start...

Terraform v1.1.7
on linux_amd64
Configuring remote state backend...
Initializing Terraform configuration...
aws_s3_bucket.public: Refreshing state... [id=www.oasys.net]
aws_s3_bucket_policy.public: Refreshing state... [id=www.oasys.net]
aws_s3_bucket_acl.public-read: Refreshing state... [id=www.oasys.net,public-read]
aws_s3_bucket_website_configuration.website: Refreshing state... [id=www.oasys.net]
aws_cloudfront_distribution.dist: Refreshing state... [id=E2GOHKG4OK8ZRL]

[...]

No changes. Your infrastructure matches the configuration.

Your configuration already matches the changes detected above. If you'd like
to update the Terraform state to match, create and apply a refresh-only plan.

real    2m28.516s
user    0m2.948s
sys     0m1.957s
```

Terraform supports (since version `0.12.11`) a `.terraformignore`
[file][terraformignore] in the root of the repository, indicating
which files/directories Terraform Cloud actually needs.  This uses the
`.gitignore` [syntax][gitignore].  In this particular case, we can
invert the logic and ignore everything *except* the needed directories.

```text
# controls what directories get uploaded to TFC for remote runs
#
# deny by default
*
# explicitly list included directories
!terraform/
```

Now runs are significantly faster:

```text
moonstone:~/www.oasys.net/terraform/(main*%=)[www-oasys-net]$ time terraform plan > /dev/null

real    0m24.708s
user    0m0.535s
sys     0m0.131s
```

[tfc]: https://cloud.hashicorp.com/products/terraform
[blog]: https://github.com/oasys/www.oasys.net.git
[hugo]: https://gohugo.io
[s3]: https://aws.amazon.com/s3/
[cloudfront]: https://aws.amazon.com/cloudfront/
[terraformignore]: https://support.hashicorp.com/hc/en-us/articles/4407839390227-Using-the-terraformignore-file-to-exclude-files-from-upload-to-Terraform-Cloud
[gitignore]: https://git-scm.com/book/en/v2/Git-Basics-Recording-Changes-to-the-Repository#_ignoring
