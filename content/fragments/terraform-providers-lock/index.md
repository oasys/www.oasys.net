---
title: "Terraform providers lock"
date: 2021-03-03T20:47:44-05:00
tags:
  - terraform
  - terraform cloud
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: |
  Resolving missing hashes in the Terraform dependency lock file.
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "terraform-lock-file-error.png"
    alt: "Terraform lock file error"
    relative: true

---

As of version 0.14, terraform now produces a `.terraform.lock.hcl` file to record
which versions of dependencies -- currently, just providers -- were chosen when
`terraform init` was run.  They recommend adding this file to your version control
system so that all future runs will use and
[verify](https://www.terraform.io/docs/language/dependency-lock.html#checksum-verification)
those same dependencies.  These can be manually upgraded by running
`terraform init -upgrade`.

I commonly will develop locally and generate the lock file on my
Mac.  Later, as I push to production, I will migrate the workspace to
[Terraform Cloud](https://www.terraform.io/cloud), and get the following
error for each provider in the lock file:

```text
Error: Failed to install provider

Error while installing hashicorp/null v3.1.0: the current package for
registry.terraform.io/hashicorp/null 3.1.0 doesn't match any of the checksums
previously recorded in the dependency lock file
```

It turns out that the way the lock file works, is to store hashes for
each of the dependencies.  These hashes, by default, are specific to the
platform the `terraform init` is run on.  When they run on the Terraform
Cloud runner -- currently Ubuntu -- the hashes will not match.  To fix
this, you can run the `terraform providers lock` command, which will
pre-populate the hashes for all platforms into your lock file.

```bash
$ terraform providers lock
- Fetching hashicorp/null 3.1.0 for darwin_amd64...
- Obtained hashicorp/null checksums for darwin_amd64 (signed by HashiCorp)

Success! Terraform has updated the lock file.

Review the changes in .terraform.lock.hcl and then commit to your
version control system to retain the new checksums.
```

```bash
$ git diff
diff --git i/terraform/.terraform.lock.hcl w/terraform/.terraform.lock.hcl
index 4b490bd..eef9494 100644
--- i/terraform/.terraform.lock.hcl
+++ w/terraform/.terraform.lock.hcl
@@ -30,6 +63,17 @@ provider "registry.terraform.io/hashicorp/null" {
   constraints = "~> 3.0"
   hashes = [
     "h1:xhbHC6in3nQryvTQBWKxebi3inG5OCgHgc4fRxL0ymc=",
+    "zh:02a1675fd8de126a00460942aaae242e65ca3380b5bb192e8773ef3da9073fd2",
+    "zh:53e30545ff8926a8e30ad30648991ca8b93b6fa496272cd23b26763c8ee84515",
+    "zh:5f9200bf708913621d0f6514179d89700e9aa3097c77dac730e8ba6e5901d521",
+    "zh:9ebf4d9704faba06b3ec7242c773c0fbfe12d62db7d00356d4f55385fc69bfb2",
+    "zh:a6576c81adc70326e4e1c999c04ad9ca37113a6e925aefab4765e5a5198efa7e",
+    "zh:a8a42d13346347aff6c63a37cda9b2c6aa5cc384a55b2fe6d6adfa390e609c53",
+    "zh:c797744d08a5307d50210e0454f91ca4d1c7621c68740441cf4579390452321d",
+    "zh:cecb6a304046df34c11229f20a80b24b1603960b794d68361a67c5efe58e62b8",
+    "zh:e1371aa1e502000d9974cfaff5be4cfa02f47b17400005a16f14d2ef30dc2a70",
+    "zh:fc39cc1fe71234a0b0369d5c5c7f876c71b956d23d7d6f518289737a001ba69b",
+    "zh:fea4227271ebf7d9e2b61b89ce2328c7262acd9fd190e1fd6d15a591abfa848e",
   ]
 }
```

Commit and add to the repo, and the Terraform Cloud run should now run
without (this) error.

![Successful run](terraform-lock-file-success.png#center)
