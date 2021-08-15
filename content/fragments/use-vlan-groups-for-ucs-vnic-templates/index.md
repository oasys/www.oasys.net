---
title: "Use VLAN groups for UCS vNIC templates"
date: 2021-08-10
tags:
  - vmware
  - ucs
  - troubleshooting
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: Troubleshooting and solution for missing VLANs
disableShare: false
disableHLJS: false
searchHidden: false

---

One of my co-workers had provisioned a new appliance VM.  It was
having connectivity problems, so he asked me to look at it.  Upon
investigation, I found:

- absolutely _no_ connectivity: `RX Packets 0` on the interface.
- this was the first/only VM in this VLAN on this vCenter cluster
- they had just added this VLAN to the dvSwitch for this project

So, I first checked what had changed most recently, the dvSwitch config.
Everything looked correct.  I compared it to other (working) VLANs, and
saw no discrepancies.

I happened to have a test VM on this cluster already provisioned, so I
added a network adapter in this VLAN to the test VM and configured the
interface with an IP.  This allowed me to verify the problem wasn't with
the appliance VM itself.  I immediately replicated the problem on my
test host, so at this point I was pretty sure the problem was upstream
of the ESX server.

Because it was easy to check, I then verified the configuration of the
network switches between the subnet gateway (a firewall) and the UCS
fabric interconnects (FIs) on which the VMware cluster was running.
The configuration looked good here, but I saw no L2 entries (`show mac
address-table vlan nnn`) on the VLAN in question towards the FI uplinks.
This was a positive sign that the problem was downstream of the switching
infrastructure.

Having looked at both "ends" of the problem, what remained between
them was the UCS FI configuration.  I logged into UCSM and checked the
networking configuration.  Indeed, the VLAN was defined and in the proper
vlan-group.  When I looked at the vNIC templates for the ESX servers,
however, I saw that the VLAN was unchecked in the VLAN list.

I could've just added the VLAN to the (fabric A and fabric B) templates
and solved the problem quickly.  Thinking about how to prevent this
kind of omission in the future, I decided instead to configure the vNIC
templates to use vlan-groups rather than individual VLANs.  We already
have a `dc-vlans` vlan-group defined for these, so in our case it was
just a matter of adding the group and then removing the (now redundant)
individual VLANs.

{{< figure src="vnic-template.png" align="center"
    caption="dialog showing VLAN group selection on a vNIC template" >}}

Now, whenever the networking team provisions a new VLAN -- or removes a
decommissioned one -- from the `dc-vlans` group, the "Updating Template"
will automatically trunk that VLAN to all the ESX servers in the cluster.

I wrote this entry as a quick note about VLAN groups, updating
templates, and an admonition to consider more general solutions than
fixing the immediate problem.  But, now I notice it ended up being more
about troubleshooting methodology:

1. collect a good definition of the problem
1. if possible, find a way to replicate the issue
1. divide and conquer to isolate the source/cause
1. propose and test a solution

This could certainly be fleshed out more.  Maybe it will be a topic in
future post.
