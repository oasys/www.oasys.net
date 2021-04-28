---
title: "Git subtree split"
date: 2021-04-28
tags:
  - git
  - puppet
  - nagios
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: |
  How to move a subdirectory of an existing repository
  to a new repository.
disableShare: false
disableHLJS: false
searchHidden: false

---

A few times in the past, I've had the need to take a subdirectory of an
existing repository and move it to a new repository, while preserving
history.  I always had to look up the syntax for `git filter-branch` to
do this; it worked, but wasn't very straightforward or easy to remember.
At some point, a `subtree split` command was added to git that makes
this process much simpler.

My real-world use case was in the migration and modernization of
our [puppet][puppet] installation.  A local module for managing our
[Opsview][opsview] installation was kept in the control repo.  Over the
years, our locally-maintained [nagios][nagios] plugins have grown to a
point where they may be better maintained in a separate repository.

[puppet]: https://puppet.com
[opsview]: https://opsview.com
[nagios]: https://www.nagios.org

First, split the subdirectory into a separate branch:

```bash
sapphire:~/puppet/(puppet6=)$ git subtree split -P site/opsview/files/plugins -b nagios-plugins
Created branch 'nagios-plugins'
6ffd1480866b514541a1ba711c85d79615211143
```

Create a new repository and pull that branch into it:

```bash
sapphire:~/puppet/(puppet6=)$ mkdir ~/noc-nagios-plugins
sapphire:~/puppet/(puppet6=)$ ^mkdir^cd
cd ~/noc-nagios-plugins
sapphire:~/noc-nagios-plugins$ git init
Initialized empty Git repository in /Users/jlavoie/noc-nagios-plugins/.git/
sapphire:~/noc-nagios-plugins/(main#)$ git pull ~/puppet nagios-plugins
remote: Enumerating objects: 76, done.
remote: Counting objects: 100% (76/76), done.
remote: Compressing objects: 100% (61/61), done.
remote: Total 76 (delta 24), reused 48 (delta 15), pack-reused 0
Unpacking objects: 100% (76/76), 239.51 KiB | 4.89 MiB/s, done.
From /Users/jlavoie/puppet
 * branch            nagios-plugins -> FETCH_HEAD
```

Push the new repository to the git server:

```bash
sapphire:~/noc-nagios-plugins/(main)$ git remote add origin git@git.bowdoin.edu:/noc/nagios-plugins.git
sapphire:~/noc-nagios-plugins/(main)$ git push -u origin main
Initialized empty Git repository in /var/lib/gitolite3/repositories/noc/nagios-plugins.git/
Enumerating objects: 76, done.
Counting objects: 100% (76/76), done.
Delta compression using up to 12 threads
Compressing objects: 100% (76/76), done.
Writing objects: 100% (76/76), 233.39 KiB | 6.67 MiB/s, done.
Total 76 (delta 26), reused 0 (delta 0), pack-reused 0
To git.bowdoin.edu:/noc/nagios-plugins.git
 * [new branch]      main -> main
Branch 'main' set up to track remote branch 'main' from 'origin'.
```

Clean up the old repo, deleting the temporary branch and associated files:

```bash
sapphire:~/noc-nagios-plugins/(main=)$ cd -
/Users/jlavoie/puppet
sapphire:~/puppet/(puppet6=)$ git br -D nagios-plugins
Deleted branch nagios-plugins (was 6ffd148).
sapphire:~/puppet/(puppet6=)$ git rm -r site/opsview/files/plugins/
rm 'site/opsview/files/plugins/check_bindhostname'
rm 'site/opsview/files/plugins/check_cisco_bgp'
rm 'site/opsview/files/plugins/check_cisco_nexus_cpu'
[ ... more plugins ... ]
sapphire:~/puppet/(puppet6+=)$ git commit -m 'migrate plugins to separate noc-nagios repo'
[ ... pre-commit hooks ... ]
[puppet6 0e70862] migrate plugins to separate noc-nagios repo
 35 files changed, 19271 deletions(-)
 delete mode 100755 site/opsview/files/plugins/check_bindhostname
 delete mode 100755 site/opsview/files/plugins/check_cisco_bgp
 delete mode 100755 site/opsview/files/plugins/check_cisco_nexus_cpu
[ ... more files ... ]
```
