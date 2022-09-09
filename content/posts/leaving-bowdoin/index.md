---
title: "Leaving Bowdoin"
date: 2022-10-03
tags:
  - career
categories:
  - networking
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: |
  Remembering my time working at Bowdoin College
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "dolphin.jpg"
    alt: "Dolphins"
    caption: "[Dolphins](https://pixabay.com/photos/dolphin-cetacean-water-jump-blue-1102987/) by [Kaedesis](https://pixabay.com/users/kaedesis-1796046/) licensed under [CC0](https://creativecommons.org/publicdomain/zero/1.0/legalcode)"
    relative: true
---

After almost 20 years at Bowdoin College, I've decided to move on.  This
has been one of the most difficult decisions of my professional career.
I thought it might be nice to mark this milestone -- or is "fork in
the road" a better metaphor? -- with a bit of a retrospective of the
projects I have initiated, led, and been involved in.  In short, this
has been a way for me to reflect on my experiences and process this
life transition.

## Email

Most day-to-day internal communication has moved to Microsoft Teams (and
before that, Slack), but for many years our primary communication was
via email.  Out of curiosity, I analyzed my sent mail folder (I only
had back to 2007) and came up with the following statistics:

- number of unique recipients: 3763
- number of `bowdoin.edu` recipients: 671
- number of sent messages: 37900

Counting business days only, that's an average of over 8 messages a day
(with a standard deviation of 7.28).  That sounds about right.

A histogram of the number of messages each year shows an interesting
trend, especially with the rapid adoption of Teams across IT in early
2020.

```text
2022: ************
2021: *************
2020: ***************
2019: ***************************
2018: ********************************
2017: *******************************
2016: *************************************
2015: ***********************************
2014: *****************************
2013: ************************************
2012: **************************************************
2011: ***************************************
2010: **************************
2009: *******************************
2008: *********************************
2007: ************************
```

## Networking

When I started at Bowdoin, we were running a single flat layer 2 network
with an IPv4 /16 stretched across the entire campus.  There was no
segmentation between server and access networks, a single core switch,
and one edge firewall and Internet circuit.  Network outages were a
regular occurrence. In those first months, the "firefighting" and stress
were so bad that I seriously considered leaving.

The network had grown organically, and was on a "upgrade a few buildings
each year" budget cycle.  With over 100 buildings, we were falling
further and further behind.  After spending the first six months
learning about the organization, the infrastructure, visiting every
single network room, and interviewing users from many different parts
of the College, I set to design a new network.  Having a supportive CIO
was critical, and in another six months we had the network completely
replaced.  I am eternally indebted to the folks that helped make
this happen, especially the dedicated staff and students that helped
with the physical deployment during the two weeks of round-the-clock
installations.  This, more than anything, formed the foundation (in both
the infrastructure and the team unity) of reliability for years to come.

When the time came, a decade later, to refresh the equipment, I had
already been planning during the previous few years to address what we
had learned from our experiences operating the network as requirements
changed and usage evolved.  The charge from the CIO was "build another
10-year network, and reduce dependence on our on-campus datacenter."
This time, in addition to upgrading everything as before, we also
re-cabled the campus datacenter, added a ten-rack datacenter at a remote
collocation facility, connected the datacenters with a path-diverse
DWDM fiber network, replaced the aging campus fiber plant, and migrated
our compute infrastructure to a new blade vendor.  The week before we
presented this plan to the board, US News [published][usnews] their
inaugural "Most Connected Colleges" report, listing us as number one
based on our existing network.  It was nice to be part of a leading
organization.

This network is still running today.  Over the past year, I have
been working on the design of the third 10-year iteration of the
network.  Applying our learnings over the past decade and bringing new
technologies to bear will hopefully make this iteration a continuing
success.  I worked closely with our vendors to hand off a working
first-pass design and bill of materials, and worked internally to secure
funding.  My hope is that this opportunity for my successor to take on
the project and make it their own will allow Bowdoin to attract a great
candidate to lead the team and infrastructure into the future.

## IP Telephony

Back in 2006, we replaced our aging [Rolm][rolm] PBX with a (then)
state-of-the-art Cisco phone system.  Despite having lots of telco
experience in my dialup and DSL ISP days troubleshooting [PRI][isdn]
configurations, this was not my area of expertise.  I looked for a
company to assist us with the design and migration, hiring and firing a
few that promised and failed.  I eventually found a small company in New
Hampshire that set up a proof-of-concept for seamless calling between
the two systems, and we hired them for the full campus migration.  Their
company has been acquired a few times since then, but we've kept in
touch over the years and have regularly hired those original engineers
to consult on the evolution of the system.

One of the interesting tasks of this project was to have accurate data
about network jack locations for [E911][e911] calls.  Cisco's Emergency
Responder could collect this information from the switches, but we did
not have full, accurate data.  I procured some handheld Sony computers,
with touchscreen, wired ethernet, wifi and cellular; installed Linux
on them and wrote a perl/Tk app that listened for CDP frames, queried
a database for location information, and presented the user with a
graphical interface for verifying or updating the data.  During that
summer, we formed teams to physically visit and plug into every one
of the (then) over 14,000 ports on campus, and set up procedures and
audit scripts to operationalize keeping this data current.  Having
standardized interface descriptions with this location information has
not only been required for the rare E911 call, but extremely useful for
day-to-day troubleshooting.

Over the past year, we've worked to migrate from that on premises
phone system to Microsoft Teams Calling, which dovetails nicely with
our increased adoption of Teams for non-voice services.  I completed
an interesting [project][e911-blog] writing some [NetBox][netbox]
customization to store and generate the location information for
integration with both the Teams API and the [Intrado][intrado]
[emergency gateway][egw].

[rolm]: https://en.wikipedia.org/wiki/ROLM
[isdn]: https://en.wikipedia.org/wiki/Primary_Rate_Interface
[e911]: https://en.wikipedia.org/wiki/Enhanced_9-1-1
[e911-blog]: https://www.oasys.net/posts/e911-with-netbox/
[netbox]: https://docs.netbox.dev/en/stable/
[intrado]: https://www.intrado.com/
[egw]: https://www.intrado.com/en/safety-services/public-safety/e911-large-enterprise

## Cloud Connectivity

In early 2019, we instituted a "Cloud First" policy in IT.  This
explicitly meant to _consider_ cloud solutions first, but still use
the right tool for the job -- not the "cloud at all costs" that
some organizations have taken it to mean.  It was evident to me
that network connectivity and provisioning would be critical to
our successful adoption of the cloud.  Using the Internet2 [Cloud
Connect][cloudconnect] L3VPN service, I was able to extend our internal
network to AWS regional [Transit Gateways][tgw] via [Direct Connect][dx]
and an Azure "hub" vNet via [ExpressRoute][expressroute] circuits.
This gave a topology where traffic between cloud providers, such as
a front-end AWS [lambda][lambda] querying an Azure [MSSQL managed
database][sqlmi], would not have to hairpin back through Maine.
Since all this infrastructure was defined as [Terraform][terraform]
workspaces, connecting new VPCs or integrating new services was
straightforward.

One of my last projects at Bowdoin was to add [Megaport][megaport]
to this build.  In the original topology, primary and secondary
connections were provisioned as an [EVC][evc] on each of our two 10Gbps
[Networkmaine][networkmaine] circuits via [Northern Crossroads][nox]
to [Internet2][i2].  If both of these paths failed (and we _did_ have
two separate incidents where that happened), traffic would fail over to
IPsec tunnels over the Internet.  This worked without issue, but was
difficult to support operationally.  I was able to simplify the network
by purchasing connectivity to Megaport via one of our other transit
providers, and [provisioning][megaport-blog] a [cloud router][mcr] (MCR)
and [virtual cross connects][vxc] to both AWS and Azure.  The MCR has a
flexible BGP configuration to be able to de-preference this path so it
is only used when the I2 path is unavailable.

[cloudconnect]: https://internet2.edu/services/cloud-connect/
[tgw]: https://aws.amazon.com/transit-gateway/
[dx]: https://aws.amazon.com/directconnect/
[expressroute]: https://azure.microsoft.com/en-us/products/expressroute/
[lambda]: https://aws.amazon.com/lambda/
[sqlmi]: https://azure.microsoft.com/en-us/products/azure-sql/managed-instance/
[terraform]: https://www.terraform.io
[megaport]: https://www.megaport.com
[evc]: https://wiki.mef.net/display/CESG/EVC+Ethernet+Services
[networkmaine]: https://networkmaine.net
[nox]: http://www.nox.org
[i2]: https://internet2.edu
[megaport-blog]: https://www.oasys.net/posts/megaport-staging-api/
[mcr]: https://www.megaport.com/services/megaport-cloud-router/
[vxc]: https://www.megaport.com/services/cloud-connectivity/

## CCoE

As the organization's adoption of cloud services increased, we decided
to form a Cloud Center of Excellence, a team with representatives
across the different groups and disciplines within the IT department.
Its charge is to foster coordination and collaboration between
groups and provide guidance on common decisions and strategy.  Our
biggest deliverable was a "Bowdoin Tagging Standards" document,
detailing required and recommended naming and tagging practices for the
organization.  I really enjoyed working through these discussions with
some of the most passionate and opinionated folks in IT, learning from
their different perspectives on technologies and approaches to building
and maintaining cloud infrastructure and services.

## Network Simplification

There used to be many separate physical "networks" for services such
as environmental control systems, door controls, and security cameras.
I was able to move every one of them to the highly-available campus
network.  These "legacy" networks of [ARCNET][arcnet] over dedicated
multimode fiber, [BACnet][bacnet] serial over long-reach twisted pair,
and other protocols over various private wireless and wired connections
were no longer ignored but converted to be part of a continuously
monitored, and managed IP network.  Migrating these services wasn't
always easy.  I learned a lot about lighting controls, managing and
troubleshooting a BACnet network across per-building subnets, and
proprietary wireless technologies.

The process of "converging" all these disparate networks took many years
to complete.  The longest holdout was the Cable TV network, a physical
plant of coax, splitters, and amplifiers to every building on campus.
We investigated and tested many solutions that would encode the video
for transport over the IP network, but each had significant drawbacks.
In the end, we migrated to the [Xfinity on Campus][xoc] service where
Comcast connects to campus via a 10Gbps peering circuit and content is
delivered to client web-based and mobile applications or set-top boxes
in the common spaces.

One of the most recent projects was a two-way radio network used by a
few groups on campus, including public safety.  This involved adding
point-to-point microwave links in addition to our dedicated fiber links,
so that each site could reach campus via multiple independently-operated
paths.  The company we contracted to design and implement the radio
system usually deploys it on a flat layer 2 network.  I learned a lot
about modern digital radios and we had a great learning experience
working with them to manage the radio system's multicast media across a
routed enterprise network.

[arcnet]: https://en.wikipedia.org/wiki/ARCNET
[bacnet]: https://en.wikipedia.org/wiki/BACnet
[xoc]: https://xfinityoncampus.com/about

## Automation

My true passion through it all has been network automation.  For
the servers and services managed by the networking team, I was an
early-adopter of [puppet][puppet] for the declarative configuration
language and the ease of [separating data and code][hiera].  In the
past 15 years, our [HPC][bowdoin-hpc] and Systems teams have each
adopted the tool for managing their respective systems.  Similarly,
[Terraform][terraform] has been an integral tool in our provisioning
process for cloud (and eventually on premises) resources.  Coupled with
[Terraform Cloud][tfc], it has enabled collaboration and transparency
between and among different IT teams.

Early on, I introduced version control using [Subversion][svn] and
later taught sessions on migrating to [Git][git] and set up our [GitHub
organization][github].  Many of the provisioning, monitoring, and audit
scripts that I've authored are in [perl][perl], and I've spent some
time in recent years migrating them to more modern [python][python]
frameworks -- or, where appropriate [moving them][perl-lambda] to a
cloud-native deployment model.  It has been immensely helpful to be able
to track changes in the infrastructure.  No one remembers the details
of a change a decade later, who made it and why.  Having the data for
our systems such as DNS, DHCP, and network configurations in git has
enabled not only tracing of change history but also workflows with
[pre-commit][precommit] hooks for testing and validation before the
changeset is deployed on production systems.

In both designs and day-to-day operations, I took every opportunity
I could find to demonstrate the value of this way of thinking.  Not
everyone was an immediate convert, but I believe that I've been able
to teach an appreciation for automation that will carry forward as
the network and systems evolve.

[puppet]: https://puppet.com
[hiera]: https://puppet.com/docs/puppet/latest/hiera_intro.html
[bowdoin-hpc]: https://www.bowdoin.edu/it/resources/high-performance-computing.html
[tfc]: https://cloud.hashicorp.com/products/terraform
[svn]: https://subversion.apache.org
[git]: https://git-scm.com
[github]: https://github.com/bowdoincollege
[perl]: https://www.perl.org
[python]: https://www.python.org
[perl-lambda]: https://www.oasys.net/posts/migrating-a-perl-cgi-to-aws-lambda/
[precommit]: https://pre-commit.com

## Internship

One of the most rewarding parts of my job was our Networking Internship
program.  The College was able to forge partnerships with the local
community colleges to offer a full-time, year-long, paid internship.
This work was typically applied to the student's senior capstone
project, but far exceeded the handful of required work hours.  The
intern was with us for an entire year, and after only a short
introduction period functioned as a full member of the networking
infrastructure team.  While performing this work, they learned about how
a real-world network was designed and operated, studied and obtained a
[CCNA][ccna] certification (some also added [JNCIA][jncia] and others),
and participated in any troubleshooting or new project work.

I've treasured the relationship with each of them, and have watched
with pride and awe as their careers progressed after their time
with our team.  The program has been on hiatus for the past few
years.  Hopefully, someone else will be able to take up the mantle
of this valuable program.  It made such a difference to not only the
participants, but to the dynamics of the work environment and to the
lives of everyone they worked with.

[ccna]: https://www.cisco.com/c/en/us/training-events/training-certifications/certifications/associate/ccna.html
[jncia]: https://www.juniper.net/us/en/training/certification/tracks/junos/jncia-junos.html

## Student Staff

Shortly after I started at Bowdoin, I took on leadership of a group of
about a dozen student employees in the networking department.  They
proudly called themselves "The Monkeys" and handled a lot of the
day-to-day grunt work, such as troubleshooting physical connectivity
issues for end users.  Many were [quick studies][quick-study] and were
soon doing operational tasks such as using [subversion][svn] to update
DNS and DHCP configurations, managing firewall rules, as well as write
automation scripts, CLI and browser-based tools for the rest of the
team.

I've felt privileged to have a small part in their college experience.
I have stayed in touch with some, but remember each of them for their
unique contributions.  I hope they remember their time as "monkeys" as
fondly, now that they have gone on to have amazing careers in their
chosen fields.

[quick-study]: https://www.merriam-webster.com/dictionary/quick%20study

## Facilities Management Liaison

Early on, I established a relationship between IT and our Facilities
Management division, who are responsible for managing everything about
the physical infrastructure of the College.  This began informally
and was later made an official role.  It entailed attending weekly
"Shops" meetings, mainly to share (and hear about) upcoming projects,
but also to be available for any questions.  It was evident that many
projects went much smoother and saved the College significant funds
and effort due to this collaboration, from the simple, "let's add some
conduit while the ground is already open for another project" to the
more complex coordination of multiple projects.

In recent years, I've delegated this role to a very capable team member.
It is comforting to leave this in capable hands, and I'm confident they
will continue to evolve this position.

## Building Projects

I have had the privilege to be involved in the design and building
of over two dozen new buildings and at least a dozen "complete"
renovations of existing buildings.  I have learned so much going
through this process with all the dedicated engineers, architects, and
project managers that made these projects a success.  By authoring and
maintaining our Division 17 and 27 standards documents, we were able
to document and streamline coordination about our requirements for all
communications infrastructure in these construction projects.

One of the greatest benefits of working at an established institution
like Bowdoin is the long-term outlook.  With a planning horizon of 50
years, I was able to build the network topology and fiber plant to be
ready to support future growth and expansion.  It was so rewarding to be
presented with a networking need, and be able to say "we were expecting
this," and to have already prepared the infrastructure years ago to be
ready to address the need with minimal effort.

Of course, the unexpected happens and project funds aren't immediately
available.  Flexibility and patience are essential.  Despite starting to
deploy single mode fiber to all new/renovated buildings since the day I
started, we had many other buildings with legacy multimode outside plant
fiber.  Using mode-conditioning patch cables, we were able to run 1Gbps
optics over this plant until the next network refresh 10 years later
when all multimode was replaced with single mode fiber (and provide
dual 10Gbps to each building).  Later, I was able to complete a 28km
fiber build from campus to a remote island [site][csc] to give full
connectivity to campus for research and learning.

I leave with two new building projects underway, and two renovations
in the planning process.  I look forward to visiting after their
completion, and watching the continued evolution of campus in the
upcoming years.

[csc]: https://www.bowdoin.edu/coastal-studies-center/

## My Take-away

After writing all of this, I've realized that the most enduring part of
the work and projects -- and the part that I will most miss -- are the
relationships.  I will remember all the wonderful people that have been
with me on this journey.  Some have stayed lifelong friends, but all
have taught me something.  Whether that teaching is about technology,
leadership, or about myself, I will treasure it.  Thank you to everyone
that made these last two decades such a special time in my career.

## What's Next?

As this chapter ends, another one starts.  I am really excited about
where I'm going next, and will focus my extra time and energy in getting
up to speed there.  I don't yet know how this will impact my blogging,
but I have found tremendous personal value in sharing some of the things
I've worked on and learned and will work to continue that practice as
time and policy permits.
