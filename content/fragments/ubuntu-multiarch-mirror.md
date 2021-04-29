---
title: "Ubuntu multiarch mirror"
date: 2021-04-22
tags:
  - linux
  - ubuntu
  - pxe
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: Adding 32bit arch to solve Ubuntu netboot issues with a local mirror.
disableShare: false
disableHLJS: false
searchHidden: false

---

I maintain a local [mirror][mirror] site for the Linux distributions we
use.  This is a simple rsync setup using [ftpsync][ftpsync] and Apache.

I recently added [Ubuntu][ubuntu] to the list, but ran into an issue
when I tested an automated install.  The installer complained it was
"Unable to locate package puppet."

In the `preseed` file, I tell the installer to also install this package
with a `pkgsel` directive.  (Later, using a `late_command` directive,
the service is configured and started.)

```text
d-i pkgsel/include string puppet
```

This worked great on Debian, but failed on the new Ubuntu mirror.  It
worked with the official mirror, though.  After a bit of investigation,
I discovered that the default Ubuntu install, unlike Debian, is
configured for multiarch (at least on the releases I tested.)

```bash
debian:~$ lsb_release -a
Distributor ID: Debian
Description:    Debian GNU/Linux 10 (buster)
Release:        10
Codename:       buster
debian:~$ dpkg --print-foreign-architectures
debian:~$
```

```bash
ubuntu:~$ lsb_release -a
Distributor ID: Ubuntu
Description:    Ubuntu 18.04.5 LTS
Release:        18.04
Codename:       bionic
ubuntu:~$ dpkg --print-foreign-architectures
i386
ubuntu:~$
```

It was failing with the new mirror because I had limited the mirrored
architectures to `amd64`, as I don't have any 32-bit installs.

```bash
ARCH_INCLUDE="amd64 source"
```

Looking at my options to fix this, I could:

1. remove the architecture with a `dpkg --remove-architecture i386`
1. try to disable multiarch with a `preseed` command
1. specify `deb [arch=amd64] https://...` in each of the apt sources
   to [override][multiarch-sources] the architectures apt uses
1. add the i386 binaries to the mirror

I wanted others to be able to use this without any additional
configuration so I chose the last option and just added `i386` to the
list in `ftpsync-ubuntu.conf` and manually ran the mirror script.

```bash
ARCH_INCLUDE="amd64 i386 source"
```

This added about 300GB to the local archive.  Now, I have fully-automated
PXE netboot installs for Ubuntu.

[ftpsync]: https://manpages.debian.org/buster/ftpsync/ftpsync.1.en.html
[mirror]: https://mirror.bowdoin.edu
[ubuntu]: https://ubuntu.com
[multiarch-sources]: https://wiki.debian.org/Multiarch/HOWTO#Setting_up_apt_sources
