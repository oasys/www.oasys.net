---
title: "Nagios check_procs unable to read output"
date: 2022-05-31
tags:
  - debian
  - nagios
  - opsview
  - puppet
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: |
  Troubleshooting a failing nagios plugin
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "double-rainbox.jpg"
    alt: "Double Rainbow"
    caption: "[Double Rainbox](https://pixabay.com/photos/rainbow-rain-landscape-nature-mood-2880471/) by [Pitsch](https://pixabay.com/users/pitsch-3124612) licensed under [CC0](https://creativecommons.org/publicdomain/zero/1.0/legalcode)"
    relative: true

---

I recently upgraded an old Debian system sitting in the lab to a modern
release.  I had neglected to keep it updated, and it was flagged on
an internal scan for having out of date software.  To prevent this
oversight in the future, I added it to our puppet deployment (so it
would get software updates and be kept in line with our standards) and
set it up in our monitoring cluster (so that we'd know if puppet or the
updates broke).

I noticed one of the monitoring checks failed: the one that checks that
the puppet agent is running.  The troubleshooting tab in the monitoring
server said that the plugin was returning "Unable to read output", so I
logged into the device to check.

```bash
root@labhost:/opt/opsview/agent/plugins# ./check_procs
Unable to read output
root@labhost:/opt/opsview/agent/plugins# ./check_procs -v
Unable to read output
root@labhost:/opt/opsview/agent/plugins# ./check_procs -vv
CMD: /usr/bin/ps axwo 'stat uid pid ppid vsz rss pcpu comm args'
Unable to read output
```

With this confirmed, I checked what the plugin was trying to do.
Fortunately, the `--verbose` option gave me the information I needed.
It was trying to run `/usr/bin/ps`.  It turns out that there is no such
binary at this path.  I checked our other installations, and that was
not the case there, so I manually fixed it.

```bash
root@labhost:/opt/opsview/agent/plugins# file /usr/bin/ps
/usr/bin/ps: cannot open `/usr/bin/ps' (No such file or directory)
root@labhost:/opt/opsview/agent/plugins# ln /bin/ps /usr/bin/ps
root@labhost:/opt/opsview/agent/plugins# ls -1i /bin/ps /usr/bin/ps
132984 /bin/ps
132984 /usr/bin/ps
```

Because the device has a funky USB serial dongle that doesn't work with
our lab console servers and I wasn't physically next to the device
during the upgrade, I didn't trust that I could easily recover from a
PXE boot and complete reinstall.

Instead of just re-imaging the device, as is the typical process, I took
advantage of Debian's long history of being upgradable between major
releases and did three `dist-upgrade`'s to get to the current version.
I think this is why `/usr/bin/ps` is different than other machines;  I
suspect there was a filesystem migration at some point in the Debian
upgrade process that caused the divergence.

I didn't investigate further, as this quickly fixed the issue.  For the
sake of keeping everything known and consistent, I'll still re-install
the machine the next time I'm physically in the lab.

All works now.

```bash
root@labhost:/opt/opsview/agent/plugins# ./check_procs
PROCS OK: 134 processes | procs=134;;;0;
```
