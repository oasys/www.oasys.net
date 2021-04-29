---
title: "Ribbon SBC interface redundancy"
date: 2021-04-29
tags:
  - voip
  - SIP
  - nexus
  - ribbon
  - sbc
categories:
  - networking
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: Dual-homing session border controllers
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "sonus_sbc2000.png"
    alt: "Sonus SBC 2000"
    caption: "Sonus SBC 2000"
    relative: true

---

## Single-homed SBC

In planning to migrate phone traffic from [PRI][PRI] to [SIP][SIP], we
decided to use an existing pair of session border controllers (SBCs)
that were already in production for another (smaller) deployment.
Before cutting over the whole organization's voice traffic, I revisited
the (3-year old) network design.  While the two SBCs are in separate
datacenters in separate buildings, each SBC is only single-homed.  This
means that there is SBC high-availability in terms of _new_ calls, but
existing calls will be dropped if there is a failure or maintenance on
the switch.

{{< figure src="single-homed.png" align="center"
  caption="Single-homed SBC" >}}

## Failover Feature

In both cases, the switch to which the SBC connects is part of a
[VPC][VPC] pair.  Devices and servers are typically dual-homed with a
[LACP/802.3ad][LACP] [MLAG][MLAG] to both switches to allow for failure
or planned maintenance.  Unfortunately, the [Ribbon SBC2000][SBC]
([formerly-named][acquisition] Sonus) devices we're using do not support
any type of link bonding.  They do, however, have a feature called
"Ethernet Redundancy for Failover" which is meant to address this use
case.

[PRI]: https://en.wikipedia.org/wiki/Primary_Rate_Interface
[SIP]: https://en.wikipedia.org/wiki/Session_Initiation_Protocol
[VPC]: https://en.wikipedia.org/wiki/EtherChannel#Virtual_PortChannel
[LACP]: https://en.wikipedia.org/wiki/Link_aggregation
[MLAG]: https://en.wikipedia.org/wiki/Multi-chassis_link_aggregation_group
[SBC]: https://ribboncommunications.com/products/enterprise-products/cloud-and-edge/session-border-controllers/sbc-2000-session-border-controller
[acquisition]: https://ribboncommunications.com/company/media-center/press-releases/sonus-networks-inc-announces-completion-sonus-and-genband-merger

Looking at the [fine manual][manual-ports], it describes the feature
succinctly:

> Ethernet Redundancy for Failover
>
> Ethernet redundancy on the SBC 1000/2000 supports continued operation
> of the SBC if failures occur regarding the underlying Ethernet service,
> such as:
>
> - Ethernet switch malfunction
> - Ethernet port malfunction

It goes on to elaborate on the deployment model, which I can summarize
in more networking-focused terms and adding some points garnered from
testing:

- This is a [L2][L2] feature; both ports must be in same subnet/VLAN.
- When the SBC detects failure on the active port, it will
  failover to the standby port with a [gratuitous ARP][GARP].
- The SBC2000 supports a maximum of two failover pairs on separate
  ports, as the device has four physical ports (in addition to one
  [oob management][oob] port).
- This feature is _not_ supported on tagged [802.1q][dot1q] ports.
- The SBC will _not_ "fail-back" when service to the original
  port is restored.

{{< disclose summary="full details from the manual" >}}

> By offering a standby Ethernet port to an active port, the SBC
> 1000/2000 allows SBC traffic to be re-directed from a primary Ethernet
> switch to an alternate Ethernet switch (within the same subnet)
> that is pre-configured (by the enterprise) with the same network
> connections as the primary Ethernet switch. The alternate switch
> is assumed capable of recognizing the introduction of live traffic
> to/from the SBC (over the standby Ethernet port) and to recover the
> outbound/inbound connections to the rest of the network.
>
> Ethernet redundancy includes:
>
> - A provisioning construct called Ethernet Redundancy Pair
> - Only one instance of pair will be supported by the SBC 1000 at any
>   given time;
> - A maximum of two instances of pair will be supported by the SBC 2000
>   at any given time;
> - Any pair must be associated with two physically distinct Ethernet
>   ports; on the SBC 2000, all Ethernet ports associated with one or
>   two pair(s) must be unique;
> - One port within the pair is selected as primary (carries all Tx and
>   Rx to a primary Ethernet switch); the other is provisioned as the
>   standby and is connected to an alternate Ethernet switch in the same
>   subnet;
> - The SBC will offer the provisioning of a single IP address to the
>   pair, to "hide" from upper SBC application layers the Ethernet
>   redundancy feature (i.e. only a single IP address may be assigned
>   to the pair).
>
> The Ethernet redundancy feature does not support load balancing,
> and does not guarantee SBC availability.

{{< /disclose >}}

[manual-ports]: https://support.sonus.net/display/UXDOC81/Managing+Ethernet+Ports
[L2]: https://en.wikipedia.org/wiki/Data_link_layer
[GARP]: https://gitlab.com/wireshark/wireshark/-/wikis/Gratuitous_ARP
[oob]: https://en.wikipedia.org/wiki/Out-of-band_management
[dot1q]: https://en.wikipedia.org/wiki/IEEE_802.1Q

## Dual-homed SBC

{{< figure src="dual-homed.png" align="center"
    caption="Dual-homed SBC" >}}

In the current deployment, each SBC is configured on two different
networks (plus the management network), a "telecom" network and a "DMZ"
network.  Since these were previously both trunked over the single
interface, they had to be moved to separate (untagged) access interfaces
in order to use the failover feature.  Fortunately for us, the device
has (just) enough physical ports for this configuration.

{{< figure src="two-networks.png" align="center"
    caption="Dual-homed SBC on two networks" >}}

## Proof of concept

As a first step in the process, we ran test cables to two unused ports
on one of the SBCs and I configured them as a failover pair on a testing
network.  Failover was less than a second, adequate for not dropping a
voice call.

To get more precise numbers of the failover time, I initiated a "flood
ping" from a nearby host.  The man page for `ping(8)` says:

```text
-f      Flood ping. For every ECHO_REQUEST sent a period ``.'' is
        printed, while for ever ECHO_REPLY received a backspace is
        printed.  This provides a rapid display of how many packets
        are being dropped.  If interval is not given, it sets interval
        to zero and outputs packets as fast as they come back or
        one hundred times per second, whichever is more.  Only the
        super-user may use this option with zero interval.

[...]

-i interval
       Wait interval seconds between sending each packet.  The default
       is to wait for one second between each packet normally, or not to
       wait in flood mode. Only super-user may set interval to values
       less 0.2 seconds.
```

This rudimentary approach allowed me to get better estimate of what the
failover time would be.  Normally, with no packet loss, there are no
dots (`.`) printed.  During the failover, as packets are dropped, the dots
are printed every 0.01 seconds until service is restored.  Counting
the number of dots gives a good estimate of the failover time.

```bash
$ sudo ping -i 0.01 -f sbc-1
PING sbc-1 (192.0.2.1) 56(84) bytes of data.
..........................................................^C
--- sbc-1 ping statistics ---
2093 packets transmitted, 2030 received, 3% packet loss, time 25078ms
rtt min/avg/max/mdev = 0.440/0.612/1.814/0.083 ms, ipg/ewma 11.987/0.607 ms
```

## Migration

### Cabling

Once this proof-of-concept test was complete, we arranged for a
datacenter tech to properly run and label three additional cables
to each SBC.  Then we scheduled a maintenance window, as the network
reconfiguration will be service-impacting.

### Back-up SBC configuration

The first step in the migration plan is to back up the configuration,
in case we needed to revert the changes.  Though we didn't need this to
restore, it proved useful later.  In the web GUI, select the "Tasks"
tab, and "Backup/Restore Config".  "Ok" will download a tar file to your
local machine.

{{< figure src="backup-config.png" align="center"
    caption="Backup Configuration" >}}

### Remove conflicting configuration

The logical VLAN interfaces cannot be deleted directly.  The VLAN itself
must be deleted by selecting the "Settings" tab and navigating to "Node
Interfaces", "Bridge", "VLAN".  From there, select the checkbox(es) and
click on the red "X".

{{< figure src="delete-vlan.png" align="center"
    caption="Delete VLAN(s)" >}}

This didn't work on my first try, as there are references elsewhere to
these VLANs.  I eventually hunted them all down:

- "Port Ethernet 1" needed both VLANs removed from the trunk
- "Port ASM 1" needed its "Default Untagged VLAN" changed
- Each "Signaling Group" needed its "Signaling/Media Source IP" changed

The first two were obvious once I thought about it, but it too me some
time to discover the last.  After poking around the web interface
looking for references, I remembered that the full XML config is in
the backup file.  I loaded up `backupconfig.xml` into my editor,
searched for references to the VLAN id, and found a match under `<Token
name="SignalingGroups">`.  Bingo!

### Configure the switches

Next, I reconfigured the network switches.  These are Cisco Nexus
switches, using port-profiles:

```cisco
port-profile type ethernet host-sbctelecom-eth
  switchport access vlan 314
  spanning-tree port type edge
  description session border controller telecom network
  state enabled
port-profile type ethernet host-sbcdmz-eth
  switchport access vlan 334
  spanning-tree port type edge
  description session border controller dmz network
  state enabled
```

switch 1:

```cisco
default int e1/4, e1/12
!
int e1/4
  inherit port-profile host-sbctelecom-eth
  description sbc-1-e1
  no shutdown
int e1/12
  inherit port-profile host-sbcdmz-eth
  description sbc-1-e3
  no shutdown
```

switch 2:

```cisco
default int e1/4, e1/12
!
int e1/4
  inherit port-profile host-sbctelecom-eth
  description sbc-1-e2
  no shutdown
int e1/12
  inherit port-profile host-sbcdmz-eth
  description sbc-1-e4
  no shutdown
```

### Test ports

On the SBC, I set the "Admin State" to enabled on all the new ports
to verify that link negotiated correctly.  I verified against the
cabling plan by manually shutting down each port on the switch side and
verifying that "Service Status" changed to "Down" on the corresponding
SBC port.

### Configure SBC IP

The IP for each failover pair is configured on the logical interface
for the that pair's primary port.  In our case, ports "Ethernet 1" and
"Ethernet 2" have their IP configured under "Node Interfaces", "Logical
Interfaces", "Ethernet 1 IP".  From here, set the "Description" to the
network name, "Admin State" to "Enabled", and "Primary Address" and
netmask/prefix for the hosts IPv4 and IPv6 addresses on that network.
I repeated the process for the other pair, under "Ethernet 3 IP".

### Configure SBC Ports

For each failover pair, I navigated to "Settings", "Node Interfaces",
"Ports", and selected the primary port in the pair.  Under "Networking",
I set the "Frame Type" to "Untagged", and the "Redundancy" to "Failover",
selecting the corresponding "Redundant Port".

{{< figure src="configure-failover.png" align="center"
    caption="Configure failover pair (Ethernet 1 / Ethernet 2)" >}}

## Final testing

Testing was relatively straightforward.  Initially I just pinged the
interface(s), executed a `shut` on the primary interface, and observed
the traffic shifting.

On the first device one interface in the pair , "Ethernet 1", didn't
work as expected.  I could see the MAC address in the L2 table on the
upstream switch, and the next-hop router would receive ARP replies and
correctly populate its ARP table, but the device would not respond to
pings.  When I failed over to the other interface, "Ethernet 2", pings
worked.  I initially thought it to be an issue on the Cisco side, as
I've had experiences in the past (with [enhanced vPC][enhanced-vpc] and
[fabric extenders][fex]) where reconfiguring an interface didn't always
"take".  In this case, it wasn't the Cisco side.  As a last resort, I
changed the ports "Redundancy" to "None", applied the change, and then
changed it back to "Failover".  That fixed the issue.  Despite following
the same steps, the other SBC didn't experience this issue.

This maintenance was coordinated in a Teams channel.  Two of the other
engineers on the call set up a new call to each other through one of
the SBCs.  They chatted while I failed the interface back and forth,
and neither could notice any interruption or degradation.  Success!

[enhanced-vpc]: https://www.cisco.com/en/US/docs/switches/datacenter/nexus5000/sw/mkt_ops_guides/513_n1_1/n5k_enhanced_vpc.html
[fex]: https://www.cisco.com/c/en/us/products/switches/nexus-2000-series-fabric-extenders/index.html
