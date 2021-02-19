---
title: "Terraform Drift Detection with GitHub Actions"
date: 2020-09-15T11:30:03+00:00
tags:
  - terraform
  - github actions
  - networking
  - cloud
categories:
  - networking
author: "Jason Lavoie"
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: |
  Using GitHub Actions to detect configuration drift in cloud
  infrastructure.
disableShare: false
disableHLJS: false
searchHidden: true

---


## The Problem

A common issue with infrastructure as code, is that it is often possible for
someone to go in after deployment and manually change things.   I still want to
preserve the *ability* for the infrastructure folks to go in and make emergency
changes, but I also want to *discourage* this practice as much as possible.

To this end, I've been using a pattern where any "out of band" changes
are alerted to the rest of the team.  That way, everyone can be aware
there was a change made, and can go back afterwards and follow the standard
procedures for the change.

## The Infrastructure

My go-to tool for building cloud infrastructure has been
[Terraform](https://www.terraform.io).  These configurations
consist of a set of git repositories connected to [Terraform
Cloud](https://www.terraform.io/cloud) (TFC) workspaces.  This allows
a streamlined workflow for collaborate on and deploy terraform
configurations.

In this case, I have used terraform to build the full network topology
between our campus network and our cloud providers.  This includes
on-prem BGP and VPN configurations, Internet2 L3VPN peerings, AWS Direct
Connect and Azure ExpressRoute connections, AWS Transit Gateways, Azure
hub vNets, and supporting services.  There are a lot of components, but
it is also a relatively static build that often goes months without any
changes.

## Drift Detection

Terraform works by storing its "known state" about how the infrastructure
it manages is configured.  When the configuration (or the real-world status)
changes, it will develop a "plan" to bring those resources back into the
expected configuration.

Drift detection works be periodically running a "terraform plan".
Terraform reaches out to the API and checks the current status and
configuration of all the managed resources.  If the real-world
status matches the expected configuration, then it reports "No
changes. Infrastructure is up-to-date."  If they don't match, then
there has been some drift and it will exit with an error sending an
alert to the team.

### GitHub Action

In each repository, we add a file to have a plan run daily.

`.github/workflows/drift.yaml`:

```yaml
name: Terraform drift

on:
  schedule:
  - cron: 0 0 * * *
jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Terraform setup
      uses: hashicorp/setup-terraform@v1
      with:
        cli_config_credentials_token: ${{ secrets.TF_API_TOKEN }}
    - name: Terraform init
      id: init
      run: terraform init
    - name: Terraform plan
      id: plan
      run: terraform plan -no-color -detailed-exitcode
```

The `-detailed-exitcode` is important here, as we want it the job to
fail if the plan detects any differences between the configuration and
the real-world resources.

### Terraform API Token

Note the `TF_API_TOKEN` secret above.  This is the token used to
authenticate to Terraform Cloud and initiate the plan.

1. Log into TFC, and create an API token.

   ![TFC create API token](tfc-create-api-token.png#center)

2. Copy the resulting API token.

   ![TFC copy API token](tfc-copy-api-token.png#center)

3. And add it to the GitHub repo.

   ![Set new GitHub Secret](github-set-secret.png#center)

This can also be done via the API or with the [Github CLI](https://cli.github.com).

```sh
$ cat | gh secret set TF_API_TOKEN -r myrepo
RCSrxQEAWW8nLg.atlasv1.pealWFEYK1uHUArZJmLw4cD2RIxyK0pOzDihUqE1PghW1HMxGD60WEOLhnok182PiCc
^D
✓ Set secret TF_API_TOKEN for myorg/myrepo
```

### Actions

Looking at the Actions tab, you can see the result of the runs and drill down
to see the details.

![GitHub Drift Success](github-drift-success.png#center)

## Conclusion

This is a really simple way to get automated feedback for any drift in your
terraform-managed infrastructure.

## Walkthrough

In sharing with the team how this works, I recorded a short video of me getting
an alert and finding the cause.  This time, it was something innocuous, but it
will also detect accidental/intentional manual changes to the infrastructure that
may have otherwise gone undetected until there was a bigger problem.

Spoiler: a new attribute was added to a provider, causing terraform to add it
to the state file.  We should probably pin the provider version in the future
to avoid this kind of issue.

{{< youtube 5p8_kwe6WVQ >}}
