---
title: "Cleaning up old git branches"
date: 2021-03-11T09:20:07-05:00
tags:
  - git
  - puppet
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: Useful commands for managing git branches in puppet environments
disableShare: false
disableHLJS: false
searchHidden: false

---

We make heavy use of [puppet environments][environments] in our
workflow.  Using [r10k][r10k], git branches are magically mapped
to environments.  This allows a process where anyone one the team
can individually work on a new feature or change, and then we can
collaborate and review/revise/test in a controlled manner.  We can
rebase to the production branch, and use the diff output as part of our
change-management documentation.  Once the change is merged, however,
sometimes the original branch is not deleted.

In doing a puppet-server migration, I decided to clean up some of these
"forgotten" branches.  Not all branches end up being merged, though;
sometimes we will prove out a change, decide not to implement it in
production, but want to keep it for future reference.  Or, maybe the
change is still a work in progress.

To list the remote branches that have already been merged (into the
`production` branch):

```bash
$ git branch -r --merged production
  remotes/origin/HEAD -> origin/production
  remotes/origin/new_feature_foo
  remotes/origin/another_change_bar
```

These can be deleted.  I can never remember the syntax for deleting a
remote branch, so I use a `nuke` alias that deletes both the local and
remote branches:

```bash
$ git config --get alias.nuke
!sh -c 'git branch -D $1 && git push origin :$1' -
$ git nuke new_feature_foo
Deleted branch new_feature_foo (was 0b43193).
remote: Deploying to puppetmaster.
remote: r10k new_feature_foo environment removed, will be purged on next run.
remote: Sending notifications.
remote: Mirroring to GitHub.
remote: To git@github.com:/bowdoincollege/noc-puppet
remote:  - [deleted]         new_feature_foo
To git.bowdoin.edu:/noc/puppet.git
 - [deleted]         new_feature_foo
```

Alternatively, you may want to see all branches that have not been
merged (yet) into the `production` branch:

```bash
$ git branch -a --no-merged production
  rejected_feature
  work_in_progress
  production
  remotes/origin/HEAD -> origin/production
  remotes/origin/rejected_feature
  remotes/origin/work_in_progress
```

I took a look at these and cleaned up what I could, but there were a
few from other team members that I didn't know about.  I asked everyone
to take a look and clean up any unneeded branches/environments.  After
they had deleted the remote branches, I was able to clean up my local
repository:

```bash
$ git remote prune origin
Pruning origin
URL: git@git.bowdoin.edu:/noc/puppet.git
 * [pruned] origin/arubaguestportal
 * [pruned] origin/freeradius_arubalab
 * [pruned] origin/freeradius_nopersontype
 * [pruned] origin/opsview_mitsubishiups
 * [pruned] origin/wlcforrancid
```

This deletes (prunes) any local tracking branches that no longer exist
on the remote.

[environments]: https://puppet.com/docs/puppet/latest/environments_about.html
[r10k]: https://github.com/puppetlabs/r10k
