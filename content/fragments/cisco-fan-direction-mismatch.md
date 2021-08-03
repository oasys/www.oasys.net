---
title: "Cisco fan direction mismatch"
date: 2021-08-03
tags:
  - cisco
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: Select the right fan and power supply module
disableShare: false
disableHLJS: false
searchHidden: false

---
Many of Cisco's switches can be purchased in two different airflow
configurations, port-side intake and port-side exhaust.  Since most
racks are designed with a front-to-back airflow, this allows for
mounting a switch in the front or back of the rack, respectively.  The
latter scenario, for example, we use for a top of rack (ToR) deployment
for server racks.

Most times, despite selling these as different SKUs, the switch is
actually the same part number, and all that differs are the part numbers
of the fans and power supplies.  Swap all of these out and now the
switch has reverse airflow.  They usually are also color-coded, with
the port-side exhaust colored blue and the port-side intake colored
red/burgundy.  The mnemonic here is "red is hot, blue is cold" -- the
exposed end of the module is either cold air in (red) or hot air out
(blue).

| Part Number       | Product Description                       |
| :---------------: | :---------------------------------------: |
| NXA-PAC-500W-PE   | Nexus 9000 500W AC PS, Port-side Exhaust  |
| NXA-PAC-500W-PE   | Nexus 9000 500W AC PS, Port-side Exhaust  |
| NXA-PDC-930W-PI   | Nexus 9000 930W DC PS, Port-side Intake   |
| NXA-PDC-930W-PE   | Nexus 9000 930W DC PS, Port-side Exhaust  |

Note the suffix convention (`-PE`, `-PI`) indicating the direction.  Older
model switches had different conventions (such as `-A` and `-B`).

The problem arises when there is a mismatch between the fan modules and
the power supply modules.  In this configuration, there is a "short
circuit" in the airflow where the hot exhaust becomes the intake
into the other module, reducing the effective cooling capacity.  In
its default configuration, a switch will detect this mismatch and
automatically shut down after a hard coded grace-period.  It will log a
message about this every minute:

```text
2021 Aug  2 08:44:35 lab-3048-1 %PLATFORM-5-MOD_STATUS: LC sub Module 1 current-status is MOD_STATUS_ONLINE/OK
2021 Aug  2 08:44:35 lab-3048-1 %MODULE-5-MOD_OK: Module 1 is online (Serial number: XXXXXXXXXXX)
2021 Aug  2 08:44:37 lab-3048-1 %ASCII-CFG-2-CONF_CONTROL: System ready
2021 Aug  2 08:45:24 lab-3048-1 %PLATFORM-0-SYS_SHUTDOWN_FAN_DIR_MISMATCH: PS/Fan-Tray Fan dir mismatch is detected - System will shutdown in 4318 minutes if mismatch is not rectified
2021 Aug  2 08:46:24 lab-3048-1 %PLATFORM-0-SYS_SHUTDOWN_FAN_DIR_MISMATCH: PS/Fan-Tray Fan dir mismatch is detected - System will shutdown in 4317 minutes if mismatch is not rectified
2021 Aug  2 08:47:24 lab-3048-1 %PLATFORM-0-SYS_SHUTDOWN_FAN_DIR_MISMATCH: PS/Fan-Tray Fan dir mismatch is detected - System will shutdown in 4316 minutes if mismatch is not rectified
2021 Aug  2 08:48:24 lab-3048-1 %PLATFORM-0-SYS_SHUTDOWN_FAN_DIR_MISMATCH: PS/Fan-Tray Fan dir mismatch is detected - System will shutdown in 4315 minutes if mismatch is not rectified
2021 Aug  2 08:49:24 lab-3048-1 %PLATFORM-0-SYS_SHUTDOWN_FAN_DIR_MISMATCH: PS/Fan-Tray Fan dir mismatch is detected - System will shutdown in 4314 minutes if mismatch is not rectified
...
```

On this lab device, there is a 72-hour grace period.  On other devices,
such as the 5596 switches, I've observed _much_ shorter times on the
order of minutes.  [I wonder if the system message author was making an
intentional pun when they used "rectified" for a power supply error.]

There exists a `no system shutdown fan-direction mismatch` command
that will, presumably, disable this protection.  I haven't tested this
personally, but I imagine it could be a handy thing to know during an
emergency if your only spare power supplies were reverse-direction and
you were able to monitor and mitigate the temperature closely.

In looking at the 9300 part list for the table above, I noticed an
entry for a `N9K-PUV-1200W`, "Nexus 9300 1200W Universal Power Supply,
Bi-directional air flow".  According to the documentation, these
"Dual-direction airflow modules automatically use the airflow direction
of the other modules installed in the switch."  These are color-coded
as "white" to differentiate them from the red/blue direction-specific
modules.
