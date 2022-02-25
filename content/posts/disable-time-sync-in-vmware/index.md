---
title: "Disable time sync in VMware"
date: 2022-02-25
tags:
  - ntp
  - vmware
  - monitoring
categories:
  - networking
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: |
  Completely disable VM time synchronization on NTP-based monitoring servers
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "big-ben.jpg"
    alt: "Big Ben"
    caption: "[Big Ben](https://pixabay.com/photos/big-ben-clock-tower-landmark-tower-6216420/) by [GiadaGiagi](https://pixabay.com/users/giadagiagi-21391229/) licensed under [CC0](https://creativecommons.org/publicdomain/zero/1.0/legalcode)"
    relative: true

---

## Background

In a recent upgrade of our monitoring infrastructure, I moved network
monitoring off of physical hardware and onto virtual machines running
on our VMware infrastructure.  The migration was completely successful
except for one small issue:  clock drift.

One of the many data points we monitor on servers and network gear
is whether their configured time is in sync with the rest of the
infrastructure.  This is done by querying their current time (usually
via NTP), and comparing it to the local monitoring server's clock (also
synced via NTP).  If the offset is larger than a threshold, an alert is
raised.  The status of the NTP servers themselves, how many peers, what
stratum, etc. is monitored separately.

## The problem

The problem was that we would intermittently -- usually during the
middle of the night -- receive a flood of alerts for every device that
particular monitoring server was monitoring.

```text
Subject: PROBLEM: NTP time is CRITICAL on host lab-lb-1
Date: Mon, 21 Feb 2022 03:19:20 -0500

PROBLEM: NTP time is CRITICAL on host lab-lb-1
Service: NTP time
Host: lab-lb-1
Alias:
Address: lab-lb-1
Host Group Hierarchy: Opsview > Networking > Lab
State: CRITICAL
Date & Time: Mon Feb 21 03:19:19 UTC 2022

Additional Information:

NTP CRITICAL: Offset -1.490670264 secs
```

And, soon after, receive notice that the alarm was cleared.

```text
Subject: RECOVERY: NTP time is OK on host lab-lb-1
Date: Mon, 21 Feb 2022 03:39:20 -0500

RECOVERY: NTP time is OK on host lab-lb-1
Service: NTP time
Host: lab-lb-1
Alias:
Address: lab-lb-1
Host Group Hierarchy: Opsview > Networking > Lab
State: OK
Date & Time: Mon Feb 21 03:39:19 UTC 2022

Additional Information:

NTP OK: Offset -0.0007096529007 secs
```

## Investigation and a solution

This was quite annoying.  I worked with our VMware administrators to
help identify the source of the problem, and to ensure it was not
configured to modify the VM's clock.  I confirmed that during an event,
the local clock of the affected monitoring server was indeed off by
over a second, and that eventually NTP would correct it.  We found that
disabling vMotion for the monitoring servers helped with the daytime
issues, but were still seeing alert floods in the early morning hours.

I finally got annoyed enough to dig a bit deeper and came up with
a solution.  VMware published a great [whitepaper][whitepaper] on
timekeeping on VMs, which was well worth my time to read.  That said,
the real key was this knowledge base [entry][kb], which explained
there are _two_ types of time corrections (their naming):

- Periodic time sync
- One-off time sync

The first, off by default, runs every minute.  The second, on my default,
runs "once" during certain events: vMotion, take or restore snapshot,
disk size adjustment, and restarting VMware Tools on the VM.  With vSphere
7.0U1 or above, both of these options are under the "VMware Tools"
settings.  We are running an older version, so I had to manually change
these options in the "Advanced" configuration settings.

[whitepaper]: https://www.vmware.com/content/dam/digitalmarketing/vmware/en/pdf/techpaper/Timekeeping-In-VirtualMachines.pdf
[kb]: https://kb.vmware.com/s/article/1189

## Step-by-step

Here are the steps to change these settings using the vSphere client.

### Shut down the VM

Either locally halt the machine or choose "Actions", "Power", "Power
Off" in the vSphere client.

{{< figure src="power.png" align="center"
    title="Power Off the VM" >}}

### Edit Settings

Once the VM is halted, select "Actions", "Settings...", and click on the
"VM Options" tab.  Under "Advanced", click "Edit Configuration...".

{{< figure src="edit-configuration.png" align="center"
    title="Advanced Edit Configuration" >}}

Per the KB article, we want to change the following seven settings:

```text
time.synchronize.continue = FALSE
time.synchronize.restore = FALSE
time.synchronize.resume.disk = FALSE
time.synchronize.shrink = FALSE
time.synchronize.tools.startup = FALSE
time.synchronize.tools.enable = FALSE
time.synchronize.resume.host = FALSE
```

In the "Configuration Parameters" dialog, click the "Add Configuration
Params" button seven times to give you enough blank fields.

{{< figure src="configuration-parameter-fields.png" align="center"
    title="Create empty Configuration Parameter Fields" >}}

Fill in the setting name and value for each entry, and click "Ok".

{{< figure src="configuration-parameters.png" align="center"
    title="Fill in each of the values" >}}

### Boot the VM

With the new settings, power on the VM.

## Results

Since I've made these changes, it has been almost a week, and we
haven't had any false NTP alerts from these monitoring servers.  It is
possible that this change may be masking an underlying problem.  I have
some time scheduled with a VMware administrator to do some additional
investigation and testing.  For now, I feel better if VMware isn't
mucking with the local clock and just relying on NTP to keep the
servers' time synchronized.
