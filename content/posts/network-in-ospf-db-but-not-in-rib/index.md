---
title: "Network in OSPF database but not in routing table"
date: 2021-11-16
tags:
  - ospf
  - ios
  - nxos
categories:
  - networking
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: Diagnosing and fixing an OSPF network type mismatch
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "cover.jpg"
    alt: ""
    caption: "[Mixed](https://pixabay.com/photos/legs-feet-different-mixed-standing-362182/) by [RyanMcGuire](https://pixabay.com/users/ryanmcguire-123690/) licensed under [CC0](https://creativecommons.org/publicdomain/zero/1.0/legalcode)"
    relative: true

---

I needed to troubleshoot a pesky OSPF issue on a new network.  It turned
out it was a simple fix, but had tripped up a couple other network
engineers so I thought I'd lab it up and document the scenario.

## The problem

The reported issue was that a network that was part of the OSPF process
was not showing up in the routing table.  Adjacencies between all routers
were up and the network in question was shown in the OSPF database.

## The solution

There was a OSPF network type mismatch between the router directly
connected to the problem network and the other routers in the network.
The other routers were configured for a `point-to-point` network type,
while the new router was left with the default `broadcast` network type
(for an ethernet interface).  Once this was fixed by setting the new
router to use `point-to-point` on those interfaces, the problem
network now showed up in the routing tables on the rest of the routers
in the network.

## Explanation

I spun up a simple lab with the minimum configuration to replicate this
issue.  Two routers, R1 and R2, connected by a single interface.  R2
has an additional network, also part of the OSPF process.  R1 sees the
remote network in the LSDB, but not in its routing table.

### Configuration

{{< figure src="topology.png" align="center"
    title="A simple two-router topology" >}}

R1:

```ios
interface GigabitEthernet1/0
 ip address 172.16.0.1 255.255.255.252
 ip ospf network point-to-point
!
router ospf 10
 network 0.0.0.0 255.255.255.255 area 0
```

R2:

```ios
interface GigabitEthernet1/0
 ip address 172.16.0.2 255.255.255.252
!
interface GigabitEthernet2/0
 ip address 10.0.2.1 255.255.255.0
!
router ospf 10
 network 0.0.0.0 255.255.255.255 area 0
```

### Problem

Adjacencies are up:

```ios
R1#sh ip os ne

Neighbor ID     Pri   State           Dead Time   Address         Interface
172.16.0.2        0   FULL/  -        00:00:37    172.16.0.2      GigabitEthernet1/0
```

```ios
R2#sh ip os ne

Neighbor ID     Pri   State           Dead Time   Address         Interface
172.16.0.1        1   FULL/BDR        00:00:37    172.16.0.1      GigabitEthernet1/0
```

(The fact that this adjacency has one peer at `FULL` and the other at
`FULL/BDR` should be a hint that there's something wrong here.)

The network is listed in the OSPF link-state database (LSDB), but does
not show up in the routing table (RIB).

```ios
R1#sh ip os da

            OSPF Router with ID (172.16.0.1) (Process ID 10)

                Router Link States (Area 0)

Link ID         ADV Router      Age         Seq#       Checksum Link count
172.16.0.1      172.16.0.1      81          0x80000009 0x007DEB 2
172.16.0.2      172.16.0.2      694         0x80000009 0x00F41E 2

                Net Link States (Area 0)

Link ID         ADV Router      Age         Seq#       Checksum
172.16.0.2      172.16.0.2      694         0x80000005 0x00D46A
R1#sh ip os da ro 172.16.0.2 | i Network
    Link connected to: a Stub Network
     (Link ID) Network/subnet number: 10.0.2.0
     (Link Data) Network Mask: 255.255.255.0
    Link connected to: a Transit Network
R1#sh ip route 10.0.2.0 255.255.255.0
% Network not in table
```

If I had not filtered the output above, IOS *does* give another hint about
the cause: "`Adv Router is not-reachable`...". (Unfortunately I don't
see about corresponding message on a similar NXOS router.)

```text {hl_lines=[7]}
R1#sh ip os da ro 172.16.0.2

            OSPF Router with ID (172.16.0.1) (Process ID 10)

                Router Link States (Area 0)

  Adv Router is not-reachable in topology Base with MTID 0
  LS age: 1039
  Options: (No TOS-capability, DC)
  LS Type: Router Links
[...]
```

### Fix

Change the OSPF network type on the interface to match.  The adjacencies
bounce, and now the route is installed in the RIB.

```ios
R2(config)#int g1/0
R2(config-if)#ip os network point-to-point
R2(config-if)#
*Nov 17 14:45:05.310: %OSPF-5-ADJCHG: Process 10, Nbr 172.16.0.1 on GigabitEthernet1/0 from FULL to DOWN, Neighbor Down: Interface down or detached
*Nov 17 14:45:05.514: %OSPF-5-ADJCHG: Process 10, Nbr 172.16.0.1 on GigabitEthernet1/0 from LOADING to FULL, Loading Done
```

```ios
R1#
*Nov 17 14:45:05.498: %OSPF-5-ADJCHG: Process 10, Nbr 172.16.0.2 on GigabitEthernet1/0 from LOADING to FULL, Loading Done
R1#sh ip route 10.0.2.0 255.255.255.0
Routing entry for 10.0.2.0/24
  Known via "ospf 10", distance 110, metric 2, type intra area
  Last update from 172.16.0.2 on GigabitEthernet1/0, 00:00:06 ago
  Routing Descriptor Blocks:
  * 172.16.0.2, from 172.16.0.2, 00:00:06 ago, via GigabitEthernet1/0
      Route metric is 2, traffic share count is 1
```

### Verify

Now, with both interfaces configured as OSPF point-to-point type, both
adjacencies show state `FULL`.  If the interfaces were both set to
the (default) broadcast type, one would show `FULL/DR` and the other
`FULL/BDR`.

```ios
R1#sh ip os ne

Neighbor ID     Pri   State           Dead Time   Address         Interface
172.16.0.2        0   FULL/  -        00:00:31    172.16.0.2      GigabitEthernet1/0
```

```ios
R2#sh ip os ne

Neighbor ID     Pri   State           Dead Time   Address         Interface
172.16.0.1        0   FULL/  -        00:00:39    172.16.0.1      GigabitEthernet1/0
```

And the "`not-reachable`" error/warning is no longer showing:

```ios

R1#sh ip os da ro 172.16.0.2

            OSPF Router with ID (172.16.0.1) (Process ID 10)

               Router Link States (Area 0)

  LS age: 371
  Options: (No TOS-capability, DC)
  LS Type: Router Links
[...]
```

## Conclusion

I generally recommend configuring an OSPF point-to-point network type
on any network links with only two devices.  It simplifies the LSDB and
associated CPU usage, but also (IMO) is a cleaner design.

That said, this practice exposes a potential for misconfiguration if
not applied consistently across the infrastructure.  Since network type
information is not carried in the OSPF packet, adjacencies are still
formed on the interface and LSDBs are synchronized between the OSPF
processes; it is only during the SPF computation that this discrepancy
manifests itself.

On balance, I still recommend setting point-to-point.  Any potential
drawbacks can be mitigated by properly templating and auditing router
configurations.
