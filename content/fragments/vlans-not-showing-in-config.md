---
title: "VLANs not showing in configuration"
date: 2021-09-27
tags:
  - cisco
  - vtp
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description:
disableShare: false
disableHLJS: false
searchHidden: false
---

I was asked to hunt down an issue where newly-created VLANs were not showing up
in the running configuration (or the startup configuration) of the switch.

```cisco
lab3850-sw-1#conf t
Enter configuration commands, one per line.  End with CNTL/Z.
lab3850-sw-1(config)#vlan 2
lab3850-sw-1(config-vlan)#name test
```

```cisco
lab3850-sw-1#sh run vlan 2
Building configuration...

Current configuration:
end
```

At first, I thought it was a corrupt VLAN database.  To test, I removed
the `vlan.dat` file and then recreated it (by adding a VLAN).  The problem
persisted.

The issue turned out to be that the switch had [VTP][vtp] configured.  The
standard configuration is to have VTP disabled, but this one switch was missing
that statement.  VTP is enabled, in "Server" mode, by default.

```cisco
lab3850-sw-1#sh vtp status
VTP Version capable             : 1 to 3
VTP version running             : 1
VTP Domain Name                 : NULL
VTP Pruning Mode                : Disabled
VTP Traps Generation            : Disabled
Device ID                       : 0c27.2497.ef00
Configuration last modified by 10.12.254.1 at 9-29-21 01:48:41
Local updater ID is 10.12.254.1 on interface Vl12 (lowest numbered VLAN interface found)

Feature VLAN:
--------------
VTP Operating Mode                : Server
Maximum VLANs supported locally   : 1005
Number of existing VLANs          : 15
Configuration Revision            : 0
MD5 digest                        : 0xF3 0x2C 0x87 0xBA 0x73 0xB9 0x79 0xE9
                                    0x72 0x10 0xAE 0x51 0x48 0xFD 0xB4 0xC4
```

Disabling VTP, by setting it to "transparent" mode, fixed the issue (and
brought the configuration in line with the standard.

```cisco
lab3850-sw-1#conf t
Enter configuration commands, one per line.  End with CNTL/Z.
lab3850-sw-1(config)#vtp mode transparent
Setting device to VTP Transparent mode for VLANS.
```

```cisco
lab3850-sw-1#sh vtp status
VTP Version capable             : 1 to 3
VTP version running             : 1
VTP Domain Name                 : NULL
VTP Pruning Mode                : Disabled
VTP Traps Generation            : Disabled
Device ID                       : 0c27.2497.ef00
Configuration last modified by 10.12.254.1 at 9-29-21 01:48:41

Feature VLAN:
--------------
VTP Operating Mode                : Transparent
Maximum VLANs supported locally   : 1005
Number of existing VLANs          : 15
Configuration Revision            : 0
MD5 digest                        : 0xF3 0x2C 0x87 0xBA 0x73 0xB9 0x79 0xE9
                                    0x72 0x10 0xAE 0x51 0x48 0xFD 0xB4 0xC4
lab3850-sw-1#sh run vlan 2
Building configuration...

Current configuration:
!
vlan 2
 name test
end
```

[vtp]: https://www.cisco.com/c/en/us/support/docs/lan-switching/vtp/10558-21.html
