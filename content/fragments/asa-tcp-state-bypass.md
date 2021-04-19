---
title: "ASA TCP state bypass"
date: 2021-04-17T09:24:08-04:00
tags:
  - Cisco
  - ASA
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: How to make a firewall not be a firewall
disableShare: false
disableHLJS: false
searchHidden: false

---

## What it does

By default an ASA does stateful inspection of all traffic.  It must see
the entire conversation to be able to set up the connection and pass the
traffic.  If traffic is asymmetric, such that the ASA only sees traffic
in one direction, the packets will not be passed.  Additionally, even if
the traffic is symmetric and a new connection is established, subsequent
fast path packets will be inspected for things such as TCP sequence
number randomization, TCP normalization, and other checks.

In order to address specific asymmetric traffic issues, or just targeted
performance problems, the `tcp-state-bypass` feature may be used to
"skip" or bypass these checks.  I've jokingly referred to this tool as
a way to "make a firewall not be a firewall."

## How to do it

First define an access list to match the interesting traffic.  Create a
`class-map` that uses that ACL, and apply it to the global `policy-map`
(or that of a specific interface).  Here you can set the connection
options.  I'd recommend you also set some limits on this traffic so
that it doesn't consume excessive resources that the inspection would
otherwise prevent.

```cisco
access-list tcp_bypass permit ip any 192.0.2.0 255.255.255.0
access-list tcp_bypass permit ip 192.0.2.0 255.255.255.0 any
class-map tcp_bypass
 description TCP traffic test network
 match access-list tcp_bypass
policy-map global_policy
 class tcp_bypass
  set connection per-client-max 10000
  set connection timeout idle 0:00:15
  set connection advanced-options tcp-state-bypass
```

Cisco has a [nice document][cisco docs] on this feature.

## Caveats

Note that this will only be used for "new" traffic.  If you are doing an
[A/B test][A/B testing], make sure you clear the existing connection(s)
after applying the policy.

Don't use this for everything.  It is a targeted tool for solving specific
network topology issues.  Make sure you understand where to tactically
apply this tool.

## Results

Note that the connection table will show the `b` flag for any connections
using this feature.

```cisco
lab-5585-1# conf t
lab-5585-1(config)# access-list tcp_bypass permit ip any 192.0.2.0 255.255.255.0
lab-5585-1(config)# access-list tcp_bypass permit ip 192.0.2.0 255.255.255.0 any
lab-5585-1(config)# class-map tcp_bypass
lab-5585-1(config-cmap)#  description TCP traffic test network
lab-5585-1(config-cmap)#  match access-list tcp_bypass
lab-5585-1(config-cmap)# policy-map global_policy
lab-5585-1(config-pmap)#  class tcp_bypass
lab-5585-1(config-pmap-c)#   set connection per-client-max 10000
lab-5585-1(config-pmap-c)#   set connection timeout idle 0:00:15
lab-5585-1(config-pmap-c)#   set connection advanced-options tcp-state-bypass
lab-5585-1(config-pmap-c)#  exit
lab-5585-1(config-pmap)# exit
lab-5585-1(config)# cle conn address 192.0.2.1
1 connection(s) deleted.
lab-5585-1(config)# show conn address 192.0.2.1
47 in use, 715 most used
TCP tcp 10.1.1.1:49528 tcp 192.0.2.1:445, idle 0:01:10, bytes 293223484, flags b
```

## Use cases

Here are a couple of real-world situations where I've used this feature:

- For a network topology where the firewalls were terminating IPsec
tunnels over the Internet to AWS and Azure as a backup for Direct
Connect and ExpressRoute circuits.  In this topology, these were the
only devices available with the crypto processing to handle the traffic.
But, in certain failure modes there was a potential for asymmetric traffic.
Specifically targeting the internal VPC/VNet networks with this feature
solved the issue.

- For a video editing platform that had network performance issues.  The
storage backend was served from a SMB fileserver, but it had suboptimal
performance though the firewall.  With an ACL matching the client(s)
and server, throughput as measured by the client was increased by 46%.
This was a simple targeted workaround to help with performance until the
network could be upgraded.

[cisco docs]: https://www.cisco.com/c/en/us/support/docs/security/asa-5500-x-series-next-generation-firewalls/118995-configure-asa-00.html
[A/B testing]: https://en.wikipedia.org/wiki/A/B_testing
