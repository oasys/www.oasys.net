---
title: "ERSPAN on Nexus"
date: 2022-03-01
tags:
  - erspan
  - tcpdump
  - cisco
  - nxos
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: Notes on how to configure ERSPAN source on a Nexus 7k
disableShare: false
disableHLJS: false
searchHidden: false

---

Today, while troubleshooting a reported SIP trunking issue, I was
seeing a firewall claiming it was transmitting packets, but they
were not seen by the downstream endpoint.  I didn't trust the ASA
packet capture in this case, so I decided to collect traffic from its
immediately-connected device, a Nexus 7009, to verify.  Cisco has a
[technote][technote] for a configuration example on this platform.

ERSPAN is handy to be able to do ad-hoc troubleshooting when you
need to a packet capture from a remote device, so I configured an
`erspan-source` session to capture traffic on that particular interface
and sent it to a remote Linux machine.

This deployment has multiple VDCs on the chassis, so the source IP of
the ERSPAN GRE tunnel needs to be configured in the admin VDC of the
box with the `global` keyword.  Note that you cannot use the management
interface on this platform.  In my particular case I used an IP of a
loopback interface in the VDC and VRF I was sourcing the traffic from.
(I haven't tested if this is required, maybe you can use any IP?)

```text
monitor erspan origin ip-address 192.0.2.1 global
```

Then, in the VDC containing the source interface, I created a monitor
session to the destination IP of the target machine.  Note that the
session is administratively disabled by default and must be manually `no
shut` to start the capture.  The exec command `show monitor` was helpful
in telling the current state of the session and whether anything is
missing from the configuration.

```text
monitor session 1 type erspan-source
  erspan-id 10
  vrf default
  destination ip 198.51.100.100
  source interface Ethernet3/23 both
  no shut
```

Traffic is encapsulated and sent to the target device.  Wireshark will
fully decode the traffic including the original packet in the GRE
payload.  In this particular situation, though, there was lots of other
traffic and I needed to filter only the packets I was concerned about.
I used packet offsets in the `tcpdump` filter expression to match UDP
(protocol 17, 0x11) source port 5060 (SIP, 0x13c4).

```text
# echo 'obase=16;5060' | bc
13C4
# tcpdump -w /tmp/erspan.pcap -c 100 -vni eth0 'proto gre and ip[59]=0x11 and ip[70:2]=0x13c4'
```

By doing a simultaneous capture both locally on the ASA and via ERSPAN
on the adjacent switch, I was able to prove that the packets in question
were indeed not on the wire.  The actual issue isn't solved, but this
allowed me to quickly isolate the problem to one device.

[technote]: https://www.cisco.com/c/en/us/support/docs/switches/nexus-7000-series-switches/113480-erspan-nexus-7k-00.html
