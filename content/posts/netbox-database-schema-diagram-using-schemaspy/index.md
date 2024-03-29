---
title: "Netbox database schema diagram using schemaspy"
date: 2021-09-14
tags:
  - netbox
  - postgresql
  - data visualization
categories:
  - networking
showToc: true
TocOpen: false
hidemeta: false
comments: false
description: Visualizing the NetBox database relationships
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "diagram.png"
    alt: "visualization of the netbox database"
    caption: "NetBox table relationship diagram generated by [SchemaSpy](https://schemaspy.org)"
    relative: true

---

While trying to wrap my head around some of the [NetBox][netbox]
database relationships, I found myself wishing for a database
schema diagram.  I looked through the documentation and [code
repo][github], but didn't find anything.  A colleague recommended trying
[schemaspy][schemaspy], so I tried it.

## Setup

I set up a fresh install of netbox on a Debian 10 VM, and downloaded
schemaspy and its dependencies.  Alternatively, they publish a Docker
[image](https://hub.docker.com/r/schemaspy/schemaspy/).

### Install Java

```bash
sudo apt install dfault-jdk
```

### JDBC Driver

PostgreSQL has a [download page][jdbc-driver] for the JDBC driver.

### Create an output directory

```bash
mkdir schemaspy
```

## Run

The documentation listed all the needed options.  Provide the path to the
drive, the database credentials, and the output directory and format, and it will
crank away on generating a report of the database structure.

```bash
$ java -jar schemaspy-6.1.0.jar -dp ./postgresql-42.2.23.jar -t pgsql11 -host localhost -db netbox -u netbox -p "$DBPW"  -o schemaspy -vizjs
  ____       _                          ____
 / ___|  ___| |__   ___ _ __ ___   __ _/ ___| _ __  _   _
 \___ \ / __| '_ \ / _ \ '_ ` _ \ / _` \___ \| '_ \| | | |
  ___) | (__| | | |  __/ | | | | | (_| |___) | |_) | |_| |
 |____/ \___|_| |_|\___|_| |_| |_|\__,_|____/| .__/ \__, |
                                             |_|    |___/

                                              6.1.0

SchemaSpy generates an HTML representation of a database schema's relationships.
SchemaSpy comes with ABSOLUTELY NO WARRANTY.
SchemaSpy is free software and can be redistributed under the conditions of LGPL version 3 or later.
http://www.gnu.org/licenses/

INFO  - Starting Main v6.1.0 on pxetest2 with PID 30796 (/home/jlavoie/schemaspy-6.1.0.jar started by jlavoie in /home/jlavoie)
INFO  - The following profiles are active: default
INFO  - Started Main in 3.304 seconds (JVM running for 4.489)
INFO  - Starting schema analysis
INFO  - Connected to PostgreSQL - 11.12 (Debian 11.12-0+deb10u1)
INFO  - Gathering schema details
Gathering schema details...........................................................................................................(1sec)
Connecting relationships...........................................................................................................(2sec)
Writing/graphing summary.INFO  - Gathered schema details in 2 seconds
INFO  - Writing/graphing summary
Warning: Nashorn engine is planned to be removed from a future JDK release
........(250sec)
Writing/diagramming detailsINFO  - Completed summary in 250 seconds
INFO  - Writing/diagramming details
........................................................................................................(561sec)
Wrote relationship details of 104 tables/views to directory 'schemaspy' in 817 seconds.
View the results by opening schemaspy/index.html
INFO  - Wrote table details in 561 seconds
INFO  - Wrote relationship details of 104 tables/views to directory 'schemaspy' in 817 seconds.
INFO  - View the results by opening schemaspy/index.html
```

## Output

After a (surprisingly) long time, it produced a browsable report in
the output directory, with lots of interesting information about the
database.

{{< figure src="browser.png" align="center" caption="SchemaSpy report" >}}

Heading over to the "Relationships" tab showed a diagram of the tables
and their relationships -- exactly what I was looking for!

{{< figure src="diagram.png" align="center"
    caption="A Section of the 'compact' Relationship Diagram" >}}

The [graphviz][graphviz] line routing leaves a bit to be desired, but
the diagram was immensely helpful in showing an overview of how the all
the object types fit together.

### Downloads

There are two diagrams generated, a "compact" and a "large".  I've
included them here for the netbox version at this time of this writing,
v3.0.2, both as the source DOT language, and the rendered SVG image.

| Compact                               | Large                               |
| :-----------------------------------: | :---------------------------------: |
| [dot](relationships.real.compact.dot) | [dot](relationships.real.large.dot) |
| [svg](relationships.real.compact.svg) | [svg](relationships.real.large.dot) |

[graphviz]: https://graphviz.org
[netbox]: https://netbox.readthedocs.io/
[github]: https://github.com/netbox-community/netbox
[schemaspy]: https://schemaspy.org
[jdbc-driver]: https://jdbc.postgresql.org/download.html
[graphviz]: https://graphviz.org
