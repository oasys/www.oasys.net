---
title: "No matching key exchange method"
date: 2021-11-30
tags:
  - ssh
  - cisco
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

After upgrading some bastion hosts to Debian 10, connections to some
older network gear failed with the following error:

```text
ssh_dispatch_run_fatal: Connection to 192.0.2.93 port 22: Invalid key length
```

It turns out that newer versions of ssh (client) now have a minimum key
length that they will negotiate.  This device had its ssh host key generated
many years ago, and a shorter key length was used:

```text
% Key pair was generated at: 18:12:01 EST Dec 27 2007
```

I needed to generate a new key with a longer key length, so I
(temporarily) installed ssh1 on the bastion host, connected to the
device, and regenerated a new key.

```text
apt install openssh-client-ssh1
```

```cisco
lab-vgw-1# conf t
lab-vgw-1(config)#crypto key generate rsa general-keys modulus ?
  <360-2048>  size of the key modulus [360-2048]

lab-vgw-1(config)#crypto key generate rsa general-keys modulus 2048
% You already have RSA keys defined named lab-vgw-1.example.com.
% They will be replaced.

% The key modulus size is 2048 bits
% Generating 2048 bit RSA keys, keys will be non-exportable...[OK]
```

Once complete, (and removing any cached host keys from
`~/.ssh/known_hosts`), I was able to log in via the regular ssh client.
