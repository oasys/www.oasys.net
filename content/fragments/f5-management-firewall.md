---
title: "F5 management firewall rules"
date: 2021-06-23
tags:
  - F5
  - NTP
  - firewall
  - monitoring
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: Permit NTP queries to management interface
disableShare: false
disableHLJS: false
searchHidden: false

---

After upgrading our F5's a while back -- probably to a BIG-IP 14.1
release, from looking at the release notes -- our monitoring of their
NTP status started failing.  One of our staff poked at it and even
opened a support case with F5, but couldn't get it working, so it ended
up on my list of things to look at.

Today, I finally spent a few minutes troubleshooting and found the
problem and an [easy fix][kb].  It appears that when they changed their
licensing model for AFM, F5 changed the way firewall rules are used on
the management interface.

By default, the following ports are permitted:

- ssh (TCP/22)
- https (TCP/443)
- SNMP (TCP/UDP/161)
- F5 HA (UDP/1026)
- F5 iQuery (TCP/4353)

All other traffic, including NTP, to the management port, is dropped.

To fix this, we just add a entry in the `management-ip-rules` configuration.

```text
security firewall management-ip-rules {
    rules {
        mgmt-ntp {
            action accept
            ip-protocol udp
            rule-number 1
            destination {
                ports {
                    123 { }
                }
            }
        }
    }
}
```

In the web UI, this is configured under "System" > "Platform" > "Security".

Via `tmsh`, use `modify /security firewall management-ip-rules ...`.

----

Interestingly, while researching this topic I found a knowledge base
[article][include] that indicates that the `/sys ntp` section has an
`include` directive that allows you to essentially put anything you want
in the `/etc/ntp.conf` file.  I haven't needed this, but it looks to be
a great configuration "escape hatch" if you need features/knobs that are
not exposed by `tmsh` or the web UI.

[kb]: https://support.f5.com/csp/article/K46122561
[include]: https://support.f5.com/csp/article/K13380
