---
title: "Tracking vendor support status in NetBox"
date: 2021-10-20
tags:
  - netbox
  - plugin
  - cisco
  - python
  - api
categories:
  - networking
showToc: false
TocOpen: false
draft: false
hidemeta: false
comments: false
description: |
  Using the Cisco EoX API to automatically update support status and dates
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "contract.png"
    alt: "Device table showing support expiry information"
    caption: "Device table showing support expiry information for a Nexus 7009 chassis"
    relative: true

---

[Timo Reimann][timo] wrote a handy [NetBox][netbox] plugin to collect
and display support expiry information (End-of-Sale, End-of-Support,
etc.) as well as the current Contract and Warranty coverage dates
for all Cisco devices defined in a NetBox installation.  His
[README][readme] does a good job showing the process for setting up the
plugin, so I won't repeat all the details here.

The general process is:

1. register an app with Cisco and obtain the API ID and secret.
1. install the plugin (`pip install netbox-cisco-support`)
1. enable the plugin (add to `PLUGINS` in `configuration.py`)
1. configure the plugin (add to `PLUGINS_CONFIG`  in `configuration.py`)
1. apply the Django migrations (`manage.py migrate`)
1. collect the EoX data (`manage.py sync_eox_data`)

If all goes well, there will now be two additional tables in the
UI device page for on any device whose manufacturer matches the
`manufacturer` value in `PLUGINS_CONFIG` (default `Cisco`).

{{< figure src="warranty.png" align="center"
    title="Device under warranty with no support contract"
    caption="(Cisco Catalyst 3850)" >}}

{{< figure src="contract.png" align="center"
    title="Device under active contract"
    caption="(Cisco Nexus 7009)" >}}

To keep the plugin working across upgrades, add the plugin to your
`local_requirements.txt`.  Also, add a cron entry to periodically update
the EoX data.

This was all pretty straightforward to me, but I thought I'd elaborate
on step 1, obtaining the API credentials.  If you are either a Smart
Net Total Care (SNTC) customer or a Partner Support Services (PSS)
partner, you are entitled to access these APIs.  If you are not already
registered, you should be able to self-register at [Smart Services
Portal][portal].  All you'll need is the serial number for one of your
devices and its associated support contract number.

{{< figure src="sntc.png" align="center"
    title="Smart Net Total Care portal" >}}

You should then be able to log into the [Cisco API Console][apiconsole],
go to [My Apps & Keys][myapps] and click "Register New App".  Fill in
the name, check "Client Credentials" and choose "EOX V5 API" and "Serial
Number to Information API Version 2", check the "I agree to the terms of
service" checkbox and click "Register".

{{< figure src="register.png" align="center"
    title="Register a new App"
    caption="Showing only the items needed" >}}

Once the App is registered, you will see the "KEY" and "CLIENT
SECRET" on the [My Apps & Keys][myapps] page.  These correspond to
the `cisco_client_id` and `cisco_client_secret` values set in
the `PLUGINS_CONFIG` variable of `configuration.py`.

{{< figure src="registered.png" align="center"
    title="Credentials for the registered App" >}}

```python
PLUGINS_CONFIG = {
    "netbox_cisco_support" : {
            "manufacturer" : "Cisco Systems",
            "cisco_client_id" : "q3ceu3gp8h8t6ss2ku59aeec",
            "cisco_client_secret" : "AqH6jqxveEruuA556TtVsSDj",
        },
}
```

Another great (python) tool I've found for interacting with these APIs
is [Dennis Roth][rothdennis]'s [cisco_support][cisco_support] package.
This makes it very easy to perform ad-hoc queries of the data, or
integrate these API requests into an existing workflow.

```python
from cisco_support import EoX

eox = EoX(client_key, client_secret)

b = eox.getByProducsIDs(['15216-OADM1-35=', 'M92S1K9-1.3.3C'])
```

[netbox]: https://netbox.readthedocs.org
[timo]: https://github.com/goebelmeier
[readme]: https://github.com/goebelmeier/netbox-cisco-support/
[portal]: https://www.cisco.com/web/smartservices/sntc.html
[apiconsole]: https://apiconsole.cisco.com
[myapps]: https://apiconsole.cisco.com/apps/myapps
[rothdennis]: https://github.com/rothdennis
[cisco_support]: https://github.com/rothdennis/cisco_support
