---
title: "Start Puppet in Debian Preseed"
date: 2021-02-19T12:06:07-05:00
tags:
  - puppet
  - debian
  - pxe
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "pxeboot.png"
    alt: "PXEboot bootscreen"
    relative: true


---

I have a nice netboot setup where we can PXEboot hosts to an automated
installer.  The last step ensures the puppet agent is running and
pointed at the correct puppetmaster.  The `.preseed` files are generated
from an erb template that ends in the following:

```ruby
[...]
<% if @distcodename == "jessie" -%>
d-i preseed/late_command string \
echo -e 'DAEMON_OPTS="--server <%= @puppetmaster %>"' > /target/etc/default/puppet ; \
rm -f /target/var/lib/puppet/state/agent_disabled.lock
<% else -%>
d-i preseed/late_command string \
in-target sed -i '/\[main\]/a server = <%= @puppetmaster %>' /etc/puppet/puppet.conf ; \
in-target ln -s /lib/systemd/system/puppet.service /etc/systemd/system/multi-user.target.wants/puppet.service
<% end -%>
```

Older distribution versions allowed us to populate the `--server` option
in `/etc/default/puppet`.  This is addressed in the first part of the if
clause.

Newer distribution versions use `systemd`, where this approach no longer
works.  In addition, the puppet agent is now disabled by default on new
installs.  The `else` clause in the second part address this case.
