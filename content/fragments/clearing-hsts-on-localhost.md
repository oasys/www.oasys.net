---
title: "Clearing HSTS on localhost"
date: 2021-06-30
tags:
  - HSTS
  - macOS
  - ssh
categories:
  - networking
showToc: false
draft: ffalse
hidemeta: false
comments: false
description: How to allow non-HTTPS connections to localhost
disableShare: false
disableHLJS: false
searchHidden: false

---

I use a few tools that create local web server:

- [vim instant markdown][instant-markdown]
- [hugo server][hugo]

These normally work well.  I also regularly will use a tunnel to a host
on another network, such as accessing an embedded management interface
of a device on an isolated network:

```bash
desktop:~$ ssh -L 8443:device:443 bastion
bastion:~$
```

The service on the remote network `device` is now available locally
via `https://localhost:443/`.  Unfortunately, when I do this, my
local browser will store these [HSTS][hsts] settings for the domain
(`localhost`, in this case) and complain/fail when one of the
above-listed tools goes to a non-HTTPS URL on `localhost`, such as
`http://localhost:8090` for instant-markdown.

What has consistently worked for me (using Safari on macOS 10.15 and
10.16) are the following steps:

```text
killall nsurlstoraged
rm -f ~/Library/Cookies/HSTS.plist
launchctl start /System/Library/LaunchAgents/com.apple.nsurlstoraged.plist
```

Followed by a restart of Safari.

[instant-markdown]: https://github.com/instant-markdown/vim-instant-markdown
[hugo]: https://gohugo.io/commands/hugo_server/
[hsts]: https://en.wikipedia.org/wiki/HTTP_Strict_Transport_Security
