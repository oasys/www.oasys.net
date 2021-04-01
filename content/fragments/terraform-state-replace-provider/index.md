---
title: "Terraform state replace provider"
date: 2021-03-31
tags:
  - terraform
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: Provider error when upgrading terraform

disableShare: false
disableHLJS: false
searchHidden: false

---

I recently had a revisit an old terraform project and update it.  I had
built a dev environment for our applications team, and they wanted to
move it to production.  Typically, whenever I go through a process like
this, I take the opportunity to update things like pre-commit hooks and
bump the terraform version to the most recent stable release.

This happened to be a migration from a 0.12.x to a 0.14.x version.
After updating the provider definitions, I ran `terraform init` and
received the following error:

```bash
sapphire:~/azure/sqlmi/(dev*$%=)[eastus]$ tf init
[...]

Initializing the backend...

Error: Invalid legacy provider address

This configuration or its associated state refers to the unqualified provider
"random".

You must complete the Terraform 0.13 upgrade process before upgrading to later
versions.


Error: Invalid legacy provider address

This configuration or its associated state refers to the unqualified provider
"azurerm".

You must complete the Terraform 0.13 upgrade process before upgrading to later
versions.
```

This is easily remedied by updating the providers in the state file:

```bash
sapphire:~/azure/sqlmi/(dev*$%=)[eastus]$ terraform state replace-provider "registry.terraform.io/-/azurerm" "hashicorp/azurerm"
Terraform will perform the following actions:

  ~ Updating provider:
    - registry.terraform.io/-/azurerm
    + registry.terraform.io/hashicorp/azurerm

Changing 25 resources:

[...]

Do you want to make these changes?
Only 'yes' will be accepted to continue.

Enter a value: yes

Successfully replaced provider for 25 resources.
sapphire:~/azure/sqlmi/(dev*$%=)[eastus]$ tf state replace-provider "registry.terraform.io/-/random" "hashicorp/random"
Terraform will perform the following actions:

  ~ Updating provider:
    - registry.terraform.io/-/random
    + registry.terraform.io/hashicorp/random

Changing 1 resources:

[...]

Do you want to make these changes?
Only 'yes' will be accepted to continue.

Enter a value: yes

Successfully replaced provider for 1 resources.
```

Now, I do a prospective plan to make everything is working as expected:

```bash
sapphire:~/azure/sqlmi/(dev*$%=)[eastus]$ tf plan
Running plan in the remote backend. Output will stream here. Pressing Ctrl-C
will stop streaming the logs, but will not stop the plan running remotely.

Preparing the remote plan...

To view this run in a browser, visit:
https://app.terraform.io/app/bowdoincollege/noc-azure-sqlmi-dev-eastus/runs/run-jEmE3ufFwWCwbjc6

Waiting for the plan to start...

Terraform v0.14.9
Configuring remote state backend...
Initializing Terraform configuration...
[...]

No changes. Infrastructure is up-to-date.

This means that Terraform did not detect any differences between your
configuration and real physical resources that exist. As a result, no
actions need to be performed.
```
