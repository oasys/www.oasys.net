---
title: "Multi-homed EC2"
date: 2021-06-22
tags:
  - aws
  - linux
  - ubuntu
  - policy routing
  - puppet
  - terraform
  - cloud-init
  - netplan
categories:
  - networking
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: |
  Using Linux policy routing on dual-homed hosts in AWS
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "split.jpg"
    alt: ""
    caption: "[Split](https://pixabay.com/photos/log-bark-ball-glass-ball-split-4164303/) by [manfredrichter](https://pixabay.com/users/manfredrichter-4055600/) licensed under [CC0](https://creativecommons.org/publicdomain/zero/1.0/legalcode)"
    relative: true

---

I had an interesting design requirement for a network monitoring host.
These monitoring hosts, or collectors, are used to monitor our network
from an external perspective -- via the Internet.  They also needed
to be reachable from our internal network for central management, and
needed access to shared internal services, such as directory services,
time servers, and central logging.

## Design

My initial approach was to deploy the hosts in a public subnet, set the
default route over the Internet, and add individual host routes via the
transit gateway to the subnet routing table.  This was not great from an
operational perspective and violated the requirements when one of the
statically-routed hosts also needed to be monitored externally.

A better approach was to dual-home the host.  Give the host two
interfaces, one in a public subnet with a default route to the Internet,
and another in a private subnet with a default route to the internal
service via a Transit Gateway (TGW) and Direct Connect (DX).  The
advantages here are that the VPC design, public and private subnets with
a default route via the TGW, matches our most common deployment pattern.
Any routing complexity is now shifted to the host, where we can make
application-specific routing choices.

This doesn't work as expected right out of the box, though.  There are
some considerations on how we set routing on a Linux host to accommodate
these requirements.

## Asymmetric routing

With the standard network configuration, there will be asymmetric
routing.  Return traffic will follow the default route in the main route
table.  If, for example, the default route is via the IGW on the public
interface, traffic received on the private interface will be responded
to via the public interface.  The return traffic will be dropped before
it gets very far at all.

{{< figure src="asymmetric.png" align="center" caption="This won't work" >}}

We want the host respond from the same interface the traffic is
received.  This [Strong end host model][strong-es] was commonly used in
[multi-homing Solaris hosts][solaris].  On Linux, we need to configure
multiple route tables and policy routing.

[strong-es]: https://datatracker.ietf.org/doc/html/rfc1122#page-108
[solaris]: https://docs.oracle.com/cd/E36784_01/html/E37475/gnkme.html

### Multiple route tables

If not specified, the `ip route` command uses the "main" route table.
Using the `table` you can specify the number of a custom route table to
use.  This allows the machine to have multiple default routes, one out
the private interface via the TGW, and one out the public interface via
the IGW.

```bash
$ cat /etc/iproute2/rt_tables
#
# reserved values
#
255     local
254     main
253     default
0       unspec
#
# local
#
#1      inr.ruhep
```

Table_ids between 1 and 252 (inclusive) are available for custom use.
Using table 10 for "private" and table 20 for "public":

```bash
$ ip route show table 10
default via 10.224.184.1 dev ens5 proto static
10.224.184.0/26 dev ens5 proto static scope link
$ ip route show table 20
default via 10.224.186.1 dev ens6 proto static
10.224.186.0/26 dev ens6 proto static scope link
```

### Policy routing

With multiple route tables, the host can control which gateway to use
for its outbound traffic, the TGW (via the private interface) or the IGW
(via the public).  To choose which table to use, we use policy routing,
which allows the kernel to [match on many different fields][ip-rule],
including source and destination addresses.

{{< figure src="symmetric-public.png" align="center"
    caption="Symmetric traffic on the public interface" >}}
{{< figure src="symmetric-private.png" align="center"
    caption="Symmetric traffic on the private interface" >}}

The [Policy Routing With Linux][book] by Matthew G. Marsh is an
excellent primer on the theory, implementation, and administration of
policy routing on Linux.

Arguably, for a host multi-homed on *n* networks, this type of
policy-routing can be accomplished with *n-1* custom route tables, by
leveraging the `main` route table.  For me, I find the consistency of
a 1:1 route table to interface mapping more straightforward to explain
and understand.

[ip-rule]: https://man7.org/linux/man-pages/man8/ip-rule.8.html
[book]: http://www.policyrouting.org/PolicyRoutingBook/

#### Match source IP

To select which table to use, create policy rules to match on the
selected source IP.  The syntax is `ip add rule from <SRC> table
<TABLE_ID>`.  For now, we just add rules to match on traffic coming from
each IP on the host.  Later, we will also add rules matching on destination
IP with the `ip add rule to <DEST> table <TABLE_ID>` syntax.

```bash
$ ip rule show
0:      from all lookup local
0:      from 10.224.186.43 lookup 20
0:      from 10.224.184.51 lookup 10
32766:  from all lookup main
32767:  from all lookup default
```

With external routing working, the host will always respond to
connections using the route table associated with the interface
on which it received the connection.

For outgoing traffic, in this configuration, it will still use
the default route in the main route table.

```bash
$ ip route show
default via 10.224.186.1 dev public proto static
10.224.184.0/26 dev ens5 proto kernel scope link src 10.224.184.51
10.224.186.0/26 dev ens6 proto kernel scope link src 10.224.186.43
```

#### Bind IP

One of the ways to route outbound traffic via a specific interface
is to "bind" that application to a specific interface/IP.  This way,
all traffic will be originated via that IP, and the policy rule will
select the appropriate table.  For example, we configure the puppet
agent to bind to the private IP:

```ini
# /etc/puppet/puppet.conf

[main]
...
sourceaddress = 10.224.184.51
```

#### Policy routes matching destination

Binding to an IP may not be supported by all applications.  A general
rule can be implemented for this by matching on the destination prefix
or IP.

```bash
$ sudo ip rule add to 1.1.1.1/32 table 10
$ ip rule show
0:      from all lookup local
0:      from 10.224.186.43 lookup 20
0:      from 10.224.184.51 lookup 10
0:      from all to 1.1.1.1 lookup 10
32766:  from all lookup main
32767:  from all lookup default
```

With this, all traffic to 1.1.1.1 (that is not sourced from a specific
IP) will use the private route table, table_id 10.

## Infrastructure as code

To implement this in a repeatable manner, I used a few different
tools.  First, [Terraform][terraform] passes a basic configuration
to [cloud-init][cloud-init] via user-data.  This hands off to
[Puppet][puppet], which adds more fine-grained application-specific
rules.

Since this particular target host is Ubuntu, we use [netplan][netplan] to
manage the host's networking.  If this were a Debian host, the same could
be implemented with the [ifupdown-multi][ifupdown-multi] package.

(I've included snippets from a larger project as an example, removing
any unrelated configuration items to help focus on how I addressed this
particular issue.)

[terraform]: https://www.hashicorp.com/products/terraform
[puppet]: https://puppet.com
[cloud-init]: https://cloudinit.readthedocs.io/en/latest/
[netplan]: https://netplan.io
[ifupdown-multi]: https://packages.debian.org/ifupdown-multi

### Terraform

The terraform AWS provider for an `aws_instance` has a `user_data`
argument which AWS passes to cloud-init on the host.  One of the
formats supported by cloud-init is the [cloud-config][cloud-config]
format, which allows [writing out arbitrary files][cloud-config-files].
Coupling this with the [templatefile][templatefile] function permits
us to dynamically generate an initial network configuration supporting
multiple route tables.

[cloud-config]: https://cloudinit.readthedocs.io/en/latest/topics/format.html#cloud-config-data
[cloud-config-files]: https://cloudinit.readthedocs.io/en/latest/topics/examples.html#writing-out-arbitrary-files
[templatefile]: https://www.terraform.io/docs/language/functions/templatefile.html

`cloud-init.tmpl`

```yaml
#cloud-config
write_files:
%{ for filename, content in write_files ~}
- encoding: b64
  owner: root:root
  path: ${filename}
  permissions: '0644'
  content: ${content}
%{ endfor ~}
runcmd:
%{ for cmd in runcmds ~}
- "${cmd}"
%{ endfor ~}
puppet:
  conf:
    main:
      sourceaddress: ${puppet_bindaddr}
    agent:
      server: ${puppet_server}
      environment: ${puppet_environment}
```

The above variables are filled in from by terraform expressions, some
parameterized as external variables, others as references to other
resource attributes.  The netplan file is supplied inline by encoding
native terraform data structure, using [base64encode][base64encode].

[base64encode]: https://www.terraform.io/docs/language/functions/base64encode.html

```terraform
resource "aws_instance" "collector" {
  count = var.collector_count
  # [...]

  network_interface {
    network_interface_id = aws_network_interface.collector_private[count.index].id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.collector_public[count.index].id
    device_index         = 1
  }

  user_data = templatefile("${path.module}/cloud-init.tmpl", {
    puppet_server      = var.puppet_server
    puppet_environment = var.puppet_environment
    puppet_bindaddr    = aws_network_interface.collector_private[count.index].private_ip
    write_files = {
      "/etc/netplan/55-terraform.yaml" = base64encode(local.netplan[count.index]),
    }
    runcmds = [
      # resolved does not work with multiple route tables
      "rm /etc/resolv.conf",
      "echo 'nameserver 169.254.169.253' > /etc/resolv.conf",
      "systemctl stop systemd-resolved.service",
      "systemctl disable systemd-resolved.service",
      # apply new network configuration
      "ip link set ${local.linux_iface["private"]} down; netplan apply",
    ]
  })
  # [...]
}
```

{{< disclose open=false
    summary="Here are some of the referenced terraform resources" >}}

```terraform
resource "aws_subnet" "private" {
  for_each          = toset(var.azs)
  vpc_id            = aws_vpc.this.id
  availability_zone = join("", [local.aws_region[var.region], each.key])
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 4, index(var.azs, each.key))
  # [...]
}

resource "aws_subnet" "public" {
  for_each          = toset(var.azs)
  vpc_id            = aws_vpc.this.id
  availability_zone = join("", [local.aws_region[var.region], each.key])
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 4, index(var.azs, each.key) + 8)
  # [...]
}

# define these separately so they persist between instance refresh
# and can be defined statically in firewall rules
resource "aws_network_interface" "collector_private" {
  count       = var.collector_count
  subnet_id   = aws_subnet.private[element(var.azs, count.index)].id
  # [...]
}

resource "aws_network_interface" "collector_public" {
  count              = var.collector_count
  subnet_id          = aws_subnet.public[element(var.azs, count.index)].id
  # [...]
}

resource "aws_eip" "collector" {
  count             = var.collector_count
  network_interface = aws_network_interface.collector_public[count.index].id
  vpc               = true
  # [...]
}
```

{{< /disclose >}}

{{< disclose open=true summary="the terraform datastructure" >}}

The `base64encode` function references the `local.netplan` variable.  Since netplan's
configuration format is yaml, I just used [yamlencode][yamlencode] on a local variable
This allows the generated file to by generated specifically with the IPs and networks
specific to the host.

[yamlencode]: https://www.terraform.io/docs/language/functions/yamlencode.html

```terraform
locals {
  linux_rt = {
    private = 10
    public  = 20
  }

  linux_iface = {
    private = "ens5"
    public  = "ens6"
  }

  netplan = [for n in range(var.collector_count) : yamlencode({
    network = {
      ethernets = {
        (local.linux_iface["private"]) = {
          dhcp4 = false
          dhcp6 = false
          addresses = [
            join("/", [
              aws_network_interface.collector_private[n].private_ip,
              split("/", aws_subnet.private[element(var.azs, n)].cidr_block)[1]
            ])
          ]
          routes = [
            {
              to    = "0.0.0.0/0"
              via   = cidrhost(aws_subnet.private[element(var.azs, n)].cidr_block, 1)
              table = local.linux_rt["private"]
            },
            {
              to    = aws_subnet.private[element(var.azs, n)].cidr_block
              via   = "0.0.0.0"
              scope = "link"
              table = local.linux_rt["private"]
            },
          ]
          routing-policy = [
            {
              from  = aws_network_interface.collector_private[n].private_ip
              table = local.linux_rt["private"]
            }
          ]
          match = {
            macaddress = aws_network_interface.collector_private[n].mac_address
          }
          set-name = "private"
        },
        (local.linux_iface["public"]) = {
          dhcp4 = false
          dhcp6 = false
          addresses = [
            join("/", [
              aws_network_interface.collector_public[n].private_ip,
              split("/", aws_subnet.public[element(var.azs, n)].cidr_block)[1]
            ])
          ]
          addresses = [
            join("/", [
              aws_network_interface.collector_public[n].private_ip,
              split("/", aws_subnet.public[element(var.azs, n)].cidr_block)[1]
            ])
          ]
          routes = [
            {
              to  = "0.0.0.0/0"
              via = cidrhost(aws_subnet.public[element(var.azs, n)].cidr_block, 1)
            },
            {
              to    = "0.0.0.0/0"
              via   = cidrhost(aws_subnet.public[element(var.azs, n)].cidr_block, 1)
              table = local.linux_rt["public"]
            },
            {
              to    = aws_subnet.public[element(var.azs, n)].cidr_block
              via   = "0.0.0.0"
              scope = "link"
              table = local.linux_rt["public"]
            },
          ]
          routing-policy = [
            {
              from  = aws_network_interface.collector_public[n].private_ip
              table = local.linux_rt["public"]
            }
          ]
          match = {
            macaddress = aws_network_interface.collector_public[n].mac_address
          }
          set-name = "public"
        }
      }
      version = 2
    }
  })]
}
```

{{< /disclose >}}

{{< disclose open=true
    summary="The generated netplan configuration file for one of the hosts" >}}

Putting it all together generates a configuration file like this in `/etc/netplan/55-terraform.yaml`

```yaml
network:
  ethernets:
    ens5:
      addresses:
      - 10.224.184.51/26
      dhcp4: false
      dhcp6: false
      match:
        macaddress: 0a:93:1b:88:fa:fb
      routes:
      - table: 10
        to: 0.0.0.0/0
        via: 10.224.184.1
      - scope: link
        table: 10
        to: 10.224.184.0/26
        via: 0.0.0.0
      routing-policy:
      - from: 10.224.184.51
        table: 10
      set-name: private
    ens6:
      addresses:
      - 10.224.186.43/26
      dhcp4: false
      dhcp6: false
      match:
        macaddress: 0a:c9:4e:3c:89:65
      routes:
      - to: 0.0.0.0/0
        via: 10.224.186.1
      - table: 20
        to: 0.0.0.0/0
        via: 10.224.186.1
      - scope: link
        table: 20
        to: 10.224.186.0/26
        via: 0.0.0.0
      routing-policy:
      - from: 10.224.186.43
        table: 20
      set-name: public
  version: 2
```

{{< /disclose >}}

For convenience sake, I've also used the [netplan feature][set-name] to rename
the interfaces, so it is easy to see at a glance which is "public" or "private"

[set-name]: https://netplan.io/reference/#common-properties-for-physical-device-types

```bash
$ ip addr show
[...]
2: private: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 0a:93:1b:88:fa:fb brd ff:ff:ff:ff:ff:ff
    inet 10.224.184.51/26 brd 10.224.184.63 scope global private
       valid_lft forever preferred_lft forever
[...]
3: public: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 0a:c9:4e:3c:89:65 brd ff:ff:ff:ff:ff:ff
    inet 10.224.186.43/26 brd 10.224.186.63 scope global public
       valid_lft forever preferred_lft forever
[...]
```

### Puppet

The host is now initialized with its initial multi-homed network
configuration.  Cloud-init has installed puppet; set the puppetserver,
environment, and sourceaddress (which binds the puppet agent to the
private IP).  Additional policy routes may be added in the puppet
manifest.

In netplan's configuration "lexicographically later files, amend
(new mapping keys) or override (same mapping keys) previous
ones."[1][netplan-override].  We generate a new netplan file that
will override the `routing-policy` on the private interface as
deployed by terraform/cloud-init, that includes the original rule
(from the private IP) and any additional routes (to the destination
IP).

Since puppet also manages the puppet agent's configuration, we add
a resource to preserve the sourceaddress setting.

[netplan-override]: https://netplan.io/reference/

```puppet
class profile::aws_collector (
  Array   $policy_routes       = [],
  String  $private_interface   = 'ens5',
  Integer $private_route_table = 10,
){

  # bind puppet agent to private interface
  puppet::config::main { 'sourceaddress':
    value => $::networking['interfaces']['private']['ip']
  }

  # add rules to to direct traffic to use the private route table
  # for certain hosts
  if !empty($policy_routes) {
    file { '/etc/netplan/60-policy-routes.yaml':
      owner   => root,
      group   => root,
      mode    => '0644',
      content => hash2yaml({
        network =>  {
          ethernets => {
            $private_interface =>  {
              'routing-policy' => $policy_routes.map |$i, String $dest| {
                {
                  to    => $dest,
                  table => $private_route_table,
                }
              } + [{
                from  => $::networking['interfaces']['private']['ip'],
                table => $private_route_table,
              }]
            }
          }
        }
      }),
    }
    ~> exec { '/usr/sbin/netplan apply': refreshonly => true, }
  }

}
```

In hiera, we list any destinations that we want policy routed via the
private interface.

```yaml
profile::aws_collector::policy_routes:
  - 192.0.2.14
  - 198.51.100.42
  - 203.0.113.22
```

This will generate a corresponding `/etc/netplan/60-policy-routes.yaml` and
trigger netplan to update the IP rules to match.

```yaml
---
network:
  ethernets:
    ens5:
      routing-policy:
      - to: 192.0.2.14
        table: 10
      - to: 198.51.100.42
        table: 10
      - to: 203.0.113.22
        table: 10
```
