---
title: Unauthenticated Git protocol
date: 2022-06-23
tags:
  - git
  - puppet
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: |
  GitHub no longer supports git:// URLs.
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "boat.jpg"
    alt: "Boat"
    caption: "[Boat](https://pixabay.com/photos/boat-rowboat-paddle-boat-water-3082540/) by [Markus Distelrath](https://pixabay.com/users/distelapparath-2726923A) licensed under [CC0](https://creativecommons.org/publicdomain/zero/1.0/legalcode)"
    relative: true
---

While updating some old code to add a small feature, I noticed a new
error in the deployment where a puppet [vcsrepo][vcsrepo] resource
was failing.

```text
Error: /Stage[main]/Mirror::Crowdstrike/Mirror::Pymirror[crowdstrike]/Vcsrepo[/opt/crowdstrike-mirror]/ensure: change from 'absent' to 'latest' failed: Execution of 'git clone git://github.com/bowdoincollege/noc-crowdstrike-mirror.git /opt/crowdstrike-mirror' returned 128: Cloning into '/opt/crowdstrike-mirror'...
fatal: unable to connect to github.com:
github.com[0: 140.82.114.4]: errno=Connection timed out
```

I logged into the box and ran the command directly to confirm.

```bash
p-mirror-a:/opt/crowdstrike-mirror$ git fetch origin
fatal: unable to connect to github.com:
github.com[0: 140.82.112.3]: errno=Connection timed out
```

This is for a public GitHub repository.  My first thought was that
we had inadvertently changed it to a private one, but that theory
was quickly disproved.  Network connectivity seemed okay, as the IP
was pingable, just not responding on that port.  This repository was
forked from another repository, and I was able to clone that without
issue.

```bash
$ git clone git://github.com/bowdoincollege/noc-crowdstrike-mirror.git
Cloning into 'noc-crowdstrike-mirror'...
fatal: unable to connect to github.com:
github.com[0: 140.82.114.4]: errno=Operation timed out

$ git clone https://github.com/oasys/crowdstrike-mirror.git
Cloning into 'crowdstrike-mirror'...
remote: Enumerating objects: 19, done.
remote: Counting objects: 100% (19/19), done.
remote: Compressing objects: 100% (14/14), done.
remote: Total 19 (delta 2), reused 19 (delta 2), pack-reused 0
Receiving objects: 100% (19/19), 5.56 KiB | 5.56 MiB/s, done.
Resolving deltas: 100% (2/2), done.
```

I couldn't see what the difference was (even though it was staring me
right in the face), so I mentioned it to a coworker.  He immediately
recognized that the failing one was using the old unauthenticated git
protocol, no longer supported by GitHub.

GitHub has a nice [blog][blog] entry about multiple changes they've
made to their supported protocols.  Under "No more unauthenticated Git",
they explain:

> On the Git protocol side, unencrypted git:// offers no integrity
> or authentication, making it subject to tampering. We expect very
> few people are still using this protocol, especially given that you
> can’t push (it’s read-only on GitHub). We’ll be disabling
> support for this protocol.

According to the blog, this final change took effect on March 15, 2022.
The fix is simply to change any `git://` remote URLs to instead use
`https://` (or `ssh://`).

[vcsrepo]: https://forge.puppet.com/modules/puppetlabs/vcsrepo
[blog]: https://github.blog/2021-09-01-improving-git-protocol-security-github/
