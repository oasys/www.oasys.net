---
title: "Override AppArmor policy for bind"
date: 2021-07-30
tags:
  - debian
  - bind
  - apparmor
  - puppet
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: Allow named to write to /etc/bind
disableShare: false
disableHLJS: false
searchHidden: false

---

After upgrading a nameserver to Debian 10, I noticed some
[AppArmor][apparmor] errors in `/var/log/auth.log`:

```text
Jul 29 09:58:18 koala audit[1676]: AVC apparmor="DENIED" operation="mknod" profile="/usr/sbin/named" name="/etc/bind/namedb/dyn/example.com.jnl" pid=1676 comm="isc-worker0029" requested_mask="c" denied_mask="
c" fsuid=112 ouid=112
```

It appears that a default [ISC bind][bind9] install now restricts
`named` to read-only access on `/etc/bind`.  According to
`/etc/apparmor.d/usr.sbin.named`:

```text
[...]
  # /etc/bind should be read-only for bind
  # /var/lib/bind is for dynamically updated zone (and journal) files.
  # /var/cache/bind is for slave/stub data, since we're not the origin of it.
  # See /usr/share/doc/bind9/README.Debian.gz
  /etc/bind/** r,
  /var/lib/bind/** rw,
  /var/lib/bind/ rw,
  /var/cache/bind/** lrw,
  /var/cache/bind/ rw,
[...]
```

The relevant portion of `/usr/share/doc/bind9/README.Debian.gz`:

```text
While you are free to craft whatever structure you wish for servers which need
to be authoritative for additional zones, what we suggest is that you put the
db files for any zones you are master for in /etc/bind (perhaps even in a
subdirectory structure depending on complexity), using full pathnames in the
named.conf file.  Any zones you are secondary for should be configured in
named.conf with simple filenames (relative to /var/cache/bind), so the data
files will be stored in BIND's working directory (defaults to /var/cache/bind).
Zones subject to automatic updates (such as via DHCP and/or nsupdate) should be
stored in /var/lib/bind, and specified with full pathnames.
```

I agree with the sentiment and philosophy behind this decision, and hope
to align my deployment with that in the future.  Right now, that is not
a simple change.  Since I currently generate the contents of `/etc/bind`
from a git repository (with some dynamic modifications) this would take
some significant work to migrate to the recommended structure.  Until
I could dedicate more testing to this, I overrode the AppArmor policy
to allow `named` to write files under `/etc/bind/` with this hack of a
puppet snippet:

```puppet
file { '/etc/apparmor.d/local/usr.sbin.named':
  content => "/etc/bind/** rw,\n",
}
~> exec { '/usr/bin/systemctl restart apparmor.service': refreshonly => true }
~> exec { '/usr/bin/systemctl restart bind9.service': refreshonly => true }
```

I did not reference `Service['bind9']` here, even though it is
already managed by puppet, as the daemon needs to be _restarted_ (not
_reloaded_) for the new policy to take effect.

[apparmor]: https://wiki.debian.org/AppArmor
[bind9]: https://www.isc.org/bind/
