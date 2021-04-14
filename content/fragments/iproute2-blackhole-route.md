---
title: "iproute2 Blackhole Route"
date: 2021-04-14
tags:
  - linux
  - routing
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: null routes with iproute2
disableShare: false
disableHLJS: false
searchHidden: false

---

Today I was doing some empirical testing of an application's behavior
when one of its authentication servers becomes unreachable.  I typically
do this with a null route on an upstream device, but noticed that
[`iproute2`][iproute2] has this built in with a nice, memorable syntax.

According to ip-route(8), one of the route types is `blackhole`:

> blackhole - these destinations are unreachable. Packets are discarded
> silently.  The local senders get an EINVAL error.

Example usage:

```bash
root@lab:~# ip route add blackhole 192.0.2.1/32
root@lab:~# ip route add blackhole 198.51.100.0/24
root@lab:~# ip route show | grep blackhole
blackhole 192.0.2.1
blackhole 198.51.100.0/24
root@lab:~# ip route del blackhole 192.0.2.1/32
root@lab:~# ip route del blackhole 198.51.100.0/24
root@lab:~# ip route show | grep blackhole
root@lab:~#
```

[iproute2]: https://wiki.linuxfoundation.org/networking/iproute2
