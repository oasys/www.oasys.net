---
title: "No matching key exchange method"
date: 2021-07-29
tags:
  - ssh
  - asa
  - debian
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: fix ssh negotiation failures to older network devices
disableShare: false
disableHLJS: false
searchHidden: false

---

After upgrading some bastion hosts to Debian 10, connections to some older network
gear failed.

Connecting to some ASA firewalls generated the error:

```text
Unable to negotiate with 203.0.113.203 port 22: no matching key exchange method found. Their offer: diffie-hellman-group1-sha1
```

This was a simple fix:

```cisco
lab-5585-1# conf t
lab-5585-1(config)# ssh key-exchange group dh-group14-sha1
lab-5585-1(config)# end
```

Some older devices, Catalyst 3750 switches and ASA 5540 firewalls,
complained of no matching cipher:

```text
%SSH-3-NO_MATCH: No matching cipher found: client chacha20-poly1305@openssh.com,aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com server aes128-cbc,3des-cbc,aes192-cbc,aes256-cbc
```

This *could* be fixed on the device with the `ip ssh server algorithm
encryption ...` (3750) and `ssh cipher encryption ...` (ASA) commands,
but I decided to fix this on the bastion host instead by adding `Ciphers
+aes256-cbc` to `/etc/ssh/ssh_config`.
