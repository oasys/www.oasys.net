---
title: "NetBox NAPALM automation with bastion host"
date: 2021-10-07
tags:
  - netbox
  - napalm
categories:
  - networking
showToc: true
TocOpen: false
hidemeta: false
comments: false
description: Configuring the NAPALM integration to use a SSH proxy
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "device.png"
    alt: "NetBox device view with additional NAPALM tabs"
    caption: "NetBox device view with additional NAPALM tabs"
    relative: true
---

[NetBox](netbox) has an available [integration](napalm-integration) with
the [NAPALM automation](napalm) library.  For supported devices, the
NetBox device view will show additional tabs for status, LLDP neighbors,
and device configuration.  It will also proxy any (read-only) napalm
getters (`get_environment`, `get_lldp_neighbors`, etc.) via the REST
API.

The basic configuration outlined in the documentation assumes that the
NetBox server has direct ssh access to these devices.  That is not the
case if you use a bastion host or jump host.  Here is how to configure
this feature to work in such an environment.

## Configure SSH

### Generate key pair

As the user that runs the netbox service create a ssh key pair.  Use an
empty passphrase.

```bash
netbox@p-netbox-a:~$ ssh-keygen -t rsa -b 4096
Generating public/private rsa key pair.
Enter file in which to save the key (/opt/netbox/.ssh/id_rsa):
Created directory '/opt/netbox/.ssh'.
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /opt/netbox/.ssh/id_rsa.
Your public key has been saved in /opt/netbox/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:OwhuO2iq3TCSgBekFx4/hID8AIzexoEP3gbehUsZJ98 netbox@p-netbox-a
The key's randomart image is:
+---[RSA 4096]----+
|O.=+=.           |
|o@.X+..          |
|= / *. E         |
|.= % .           |
|o + .   S        |
|.o . . . .       |
|o o.o . o        |
| oo=..   .       |
|+o. o.           |
+----[SHA256]-----+
```

Add the public key to the `~/.ssh/authorized_hosts` in the target user
account on the bastion host.  In our configuration, this is an account
(same username, `netbox`) without password authentication enabled, so
we use puppet to synchronize the keys.  In a simpler system, you can
just use `ssh-copy-id`, something like:

```bash
netbox@p-netbox-a:~$ ssh-copy-id netbox@bastion
/usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/opt/netbox/.ssh/id_rsa.pub"
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
Password:

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'netbox@bastion'"
and check to make sure that only the key(s) you wanted were added.

```

### Custom ssh configuration

Create a custom ssh configuration file on the NetBox server,
`/opt/netbox/.ssh/napalm.config`:

```text
Host bastion
  StrictHostKeyChecking accept-new
  IdentitiesOnly yes
  BatchMode yes
  PreferredAuthentications publickey

Host *
  ProxyCommand ssh -F ~/.ssh/napalm.config -W %h:%p bastion
  PubkeyAuthentication no
  StrictHostKeyChecking no
```

Using this configuration file will direct the ssh client (and NAPALM)
to proxy all requests via the bastion server.  A separate configuration
file is used to avoid affecting ssh client behavior for other uses.
The `StrictHostKeyChecking` options allow ssh to learn the bastion's
host key the first time but warn about any future changes (`accept-new`),
while ignoring (`no`) any changes in the end devices' host keys.  The
`PreferredAuthentications publickey` and `PubkeyAuthentication no` speed
up session start-up time to the bastion and device by prioritizing the
authentication method each will use.

## Configure NetBox

### Install the `napalm` library

```bash
echo napalm >> /opt/netbox/local_requirements.txt
/opt/netbox/venv/bin/pip install -r /opt/netbox/local_requirements.txt
```

### Configure NAPALM credentials

In `configuration.py` set the following variables:

```python
NAPALM_USERNAME = 'netbox'
NAPALM_PASSWORD = 'device_password'
NAPALM_ARGS = { "ssh_config_file" : "/opt/netbox/.ssh/napalm.config" }
```

The username and password are the credentials to authenticate to the
network device itself.  In our case, that is a `aaa` user on the
TACACS+ servers (with limited read-only access to the devices).

### Configure Platforms

For each of your configured platforms, ensure the `napalm_driver`
attribute is set to match the corresponding [NAPALM driver name](napalm-drivers).

{{< figure src="platforms.png" align="center"
    title="Configure NAPALM driver for each Platform" >}}

### Configure Devices

For each of the supported devices, ensure that the `status` is "Active"
and that a primary IP is assigned.  Users with the appropriate
`dcim.napalm.read_device` permission will see the additional NAPALM
tabs in the device view.

## Results

### Web UI view

{{< figure src="device.png" align="center"
    title="Device view with additional NAPALM tabs" >}}

### API access

Data can also be retrieved via the REST API for any of the available
[NAPALM getters](napalm-getters).

{{< figure src="api.png" align="center"
    title="REST API query for get_interface_counters" >}}

[netbox]: https://github.com/netbox-community/netbox
[napalm]: https://github.com/napalm-automation/napalm
[napalm-drivers]: https://napalm.readthedocs.io/en/latest/support/#general-support-matrix
[napalm-getters]: https://napalm.readthedocs.io/en/latest/support/#getters-support-matrix
[napalm-integration]: https://netbox.readthedocs.io/en/stable/additional-features/napalm/
