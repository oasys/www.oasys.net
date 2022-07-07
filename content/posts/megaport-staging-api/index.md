---
title: "Using the Megaport staging API with Terraform"
date: 2022-07-06
tags:
  - megaport
  - terraform
  - bgp
categories:
  - networking
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: |
  Megaport offers a "staging sandbox" portal and API for
  testing and validating integrations with tools such as Terraform.
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "cover.png"
    alt: "Megaport and Terraform logos"
    relative: true

---

I have been working on rearchitecting our backup cloud connectivity
and am considering using [Megaport][megaport]'s [cloud router][mcr]
(MCR) product.  I'll post again in the future with more details of the
design and its implementation, but I wanted to write a short note of
appreciation about Megaport's provisioning interface.

They provide a complete self-service [portal][portal] and [REST
API][api].  In addition, they provide a separate "staging"
[portal][staging-portal] and [API][staging-api], where "all actions
mirror the production system, but services will not be deployed and you
will not be billed for any activity."

{{< figure src="portal.png" align="center"
    title="Megaport Staging Portal" >}}

I think this is wonderful, and wish more providers offered this
service.  Before I purchased anything, I wanted to validate that my
expected design would work the way I planned.  I was able to register an
account and test provisioning the services without having to engage a
salesperson.

Note that there is a 24 hour delay before new accounts have access to
staging.  Also, every day everything in staging is clobbered and all
services configured in the current production environment are synced to
the staging environment.

For this project, I specifically wanted to use their
[terraform][terraform] [provider][provider] to build an MCR and Azure
and AWS virtual cross connects (VXCs).  This was as simple as supplying
portal credentials and specifying the `environment` to use the staging
API.

```terraform
terraform {
  required_providers {
    megaport = {
      source  = "megaport/megaport"
      version = ">=0.2.5"
    }
  }
}

provider "megaport" {
  username = "myportalusername"
  password = "myportalpassword"
  accept_purchase_terms = true
  delete_ports          = true
  environment           = "staging"
}
```

Before creating the first resource, I found that I needed to enable for
the market(s) where I was provisioning services, "USA Market" in this
case.

{{< figure src="enable-market.png" align="center"
    title="Enable Markets before using Terraform"
    caption="Choose `Billing Markets` under the `Company` menu" >}}

Instantiating the cloud router (MCR) involves specifying its location.
The provider has a [location data source][location] to lookup by name.

```terraform
data "megaport_location" "datacenter" {
  name    = "Equinix DC4"
  has_mcr = true
}

resource "megaport_mcr" "mcr" {
  mcr_name    = "ashburn-mcr"
  location_id = data.megaport_location.datacenter.id

  router {
    port_speed    = 1000
    requested_asn = 133937
  }
}
```

The cloud VXCs can be configured using `megaport_aws_connection` and
`megaport_azure_connection` resources.  There is a [partner port data
source][partner-port] that allows lookup of each by company and name.

```terraform
data "megaport_partner_port" "aws_port" {
  connect_type = "AWS"
  company_name = "AWS"
  product_name = "US East (N. Virginia) (us-east-1)"
  location_id  = data.megaport_location.datacenter.id
}

resource "megaport_aws_connection" "aws_vxc" {
  vxc_name   = "AWS"
  rate_limit = 500

  a_end { port_id = megaport_mcr.mcr.id }

  csp_settings {
    requested_product_id = data.megaport_partner_port.aws_port.id
    amazon_asn           = 65301
    amazon_account       = "123456789012"
  }
}
```

{{< figure src="provisioned.png" align="center"
    title="MCR with virtual cross-connects to AWS and Azure" >}}

This process provisions the MCR with default IPs and a IPv4
BGP session.  I also verified (not shown here) how to use the
`a_end_mcr_configuration` argument to specify from terraform custom
IP addresses, multiple BGP sessions with individualized [advanced
settings][bgp-advanced] for [BFD][bfd], [MED][med], and MD5
authentication in a dual-stack configuration.

Unfortunately, I can't configure any physical connections using the
staging API.  Actual connections into our on-prem datacenters and the
cloud providers will need to wait until I'm a paying customer.  For now,
this gave me the confidence to judge that I can integrate the provisioning
of Megaport resources into our existing Terraform workflows.

[megaport]: https://www.megaport.com
[mcr]: https://www.megaport.com/services/megaport-cloud-router/
[portal]: https://portal.megaport.com/
[api]: https://api.megaport.com/
[staging-portal]: https://portal-staging.megaport.com/
[staging-api]: https://api-staging.megaport.com/
[terraform]:  https://www.terraform.io
[provider]: https://registry.terraform.io/providers/megaport/megaport/latest
[location]: https://registry.terraform.io/providers/megaport/megaport/latest/docs/data-sources/megaport_location
[partner-port]: https://registry.terraform.io/providers/megaport/megaport/latest/docs/data-sources/megaport_partner_port
[advanced-settings]: https://docs.megaport.com/mcr/mcr-bgp-advanced/
[bfd]: https://en.wikipedia.org/wiki/Bidirectional_Forwarding_Detection
[med]: https://en.wikipedia.org/wiki/Border_Gateway_Protocol#Multi-exit_discriminators
