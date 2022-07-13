---
title: "List All Certificates Issued for a Domain"
date: 2022-07-13
tags:
  - TLS
  - cloudflare
  - sectigo
  - certificates
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: |
  Tools to generate reports and monitor certificate transparency logs.
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "pile-of-wood.jpg"
    alt: "Pile of Wood"
    caption: "[Pile of Wood](https://pixabay.com/photos/pile-of-wood-dirt-road-eve-mood-5190709/) by [MarianF](https://pixabay.com/users/marianf-1421292/) licensed under [CC0](https://creativecommons.org/publicdomain/zero/1.0/legalcode)"
    relative: true

---

The [certificate transparency project][ct] maintains logs of all
certificates issued.  My understanding is that this was originally
started by Google, but is now a distributed trust network where all
[CA][ca]s submit certificates to at least two "public logs."  This
means that there is a collective, verifiable data about all trusted
certificates on the Internet.

From a security perspective it is helpful to have a full inventory
of all certificates issued for your domain(s).  More importantly is
knowing when illegitimate certificates have been issued, due to a rogue
or reckless CA or the failure of internal approval processes.  A few
companies have built tools and services to monitor the transparency logs
to report this information.

The project has a [list][monitors] of these monitor services.  Two that
I use are shown below.

## crt.sh

[Sectigo][sectigo] has made the [crt.sh][crt] tool available for
filtering the logs by a particular domain.  I find that excluding
expired certificates and turning on deduplication gives the most usable
[output][crt-oasys].  Note that there is also an RSS feed link so you
can subscribe to any new entries for that search.

{{< figure src="crtsh-oasys.png" align="center"
    title="crt.sh report for oasys.net" >}}

## cloudflare

[Cloudflare][cloudflare] offers [Certificate Transparency
Monitoring][cloudflare-ctm] to all of its customers.  It is as simple
as turning on a switch for that particular zone in their dashboard.
Choose the domain/zone that you are interested in monitoring, and under
the `SSL/TLS` menu, choose `Edge Certficates`.  Scroll down and enable
"Certificate Transparency Monitoring."

{{< figure src="cloudflare-ctm.png" align="center"
    title="enable certificate transparency monitoring in the dashboard" >}}

[ct]: https://certificate.transparency.dev
[ca]: https://en.wikipedia.org/wiki/Certificate_authority
[monitors]: https://certificate.transparency.dev/monitors/
[sectigo]: https://sectigo.com
[crt]: https://crt.sh
[crt-oasys]: https://crt.sh/?Identity=oasys.net&exclude=expired&deduplicate=Y
[cloudflare]: https://www.cloudflare.com
[cloudflare-ctm]: https://blog.cloudflare.com/introducing-certificate-transparency-monitoring/
