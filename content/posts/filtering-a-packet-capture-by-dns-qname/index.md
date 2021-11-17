---
title: "Filtering a packet capture by DNS Query Name"
date: 2021-10-28
tags:
  - DNS
  - tcpdump
  - wireshark
  - tshark
  - apparmor
categories:
  - networking
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: Using tshark display filters with a tcpdump post-rotate script to capture an intermittent problem on a busy DNS server
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "cover.jpg"
    alt: "Fire Hydrant Flushing"
    caption: "[Hydrant](https://pixabay.com/photos/hydrant-fire-plug-vented-flushing-2838016/) by [Denise McQuillen](https://pixabay.com/users/macdeedle-6173261) licensed under [CC0](https://creativecommons.org/publicdomain/zero/1.0/legalcode)"
    relative: true

---

## Overview

An application problem was brought to me to troubleshoot.  From
the symptoms I observed, I was confident that the problem was an
intermittent issue with the SAAS provider's DNS.  To prove this
assertion, I needed to collect a packet capture of failed query.  This
post details the process I went through to collect that data.

## Investigation

When the problem was reported, we saw our recursive nameservers
returning NXDOMAIN in response to queries for the domain, when
manual queries (with `dig`) directly to the provider's nameservers
returned valid data.  As soon as the entry expired from the recursive
nameserver's cache, it was queried anew, and the reported issue was
temporarily resolved.  Based on this, my theory was that one of the SAAS
provider's -- or their DNS provider's -- nameservers was occasionally
responding with a negative answer to the query.  I wanted to capture
this response packet to help isolate and fix the problem.

## Filter

The problem only seemed to occur a couple times a day.  It isn't
feasible to do a full packet capture for all DNS traffic on these
servers for that length of time, so I needed a quick way to filter for
only the domain(s) in question.

### Capture Filter

My first thought was to use a capture filter.  I quick search turned up
a Stack Exchange [post][stackexchange] with an example, but that seemed a
bit too complicated, especially since in this particular case there are
multiple long domain names that I need to look for.

```bash
$ printf foo | xxd -p
666f6f
$ tshark -n -T fields -e dns.qry.name -f "src port 53 and $(awk '
    BEGIN{
      for(i=0;i<250;i++) {
        printf sep "(udp[%d]!=0&&((udp[%d:4]&0xffffff00)==0x666f6f00", i+20, i+20
        c = c "))"; sep = "||"
      }
      print c
    }')"
```

[stackexchange]: https://unix.stackexchange.com/questions/393382/how-to-filter-dns-queries-by-dns-qry-name-in-tshark

### Display Filter

Wireshark (and `tshark`) have _display_ filters that decode many
different protocols -- including [DNS][wireshark-dns] -- and easily
allow filtering DNS packets by query name.  I started a local Wireshark
session on my desktop and quickly determined a working filter for my
use-case: `dns.qry.name ~ ebscohost.com or dns.qry.name ~ eislz.com`.
This particular service was a chain of multiple CNAMEs, such as
`af-ehost-gateway-ehost-live-pi-external.ehost-live.eislz.com.`, and I
wanted to capture anything within those two domains.

{{< figure src="wireshark-local.png" align="center"
    caption="Local Wireshark session to determine display filter" >}}

[wireshark-dns]: https://www.wireshark.org/docs/dfref/d/dns.html

### Failure

"Easy," I said to myself.  But, as soon as I tried it I realized that
using a display filter in a single command that captures and displays
isn't supported.

```bash
$ tshark -w /tmp/ebscohost.pcap -s 1500 -i enp6s0 -Y 'dns.qry.name ~ ebscohost.com or dns.qry.name ~ eislz.com'
tshark: Display filters aren't supported when capturing and saving the captured packets.
```

Apparently, this [used to work][tshark-filtering], but has been removed
as part of some security refactoring.

[tshark-filtering]: https://gitlab.com/wireshark/wireshark/-/issues/2234

## Two Stages

At this point, I realized I would have to do this in two stages, one for
capture and one for filtering.   I opted to use `tcpdump`'s option (`-C`)
for automatically rotating the save file based on size, and the post-rotate
command (`-z`) option to run a filter and clean-up script after each rotation.

The filter and clean-up script, `/tmp/dns_filter.sh`:

```bash
#!/bin/bash

OUT="${1%%.*}.$(date +'%Y-%m-%d-%T').pcap"
FILTER='dns.qry.name ~ ebscohost.com or dns.qry.name ~ eislz.com'

tshark -s 1500 -r $1 -w $OUT -Y $FILTER

if [ $(tshark -r $OUT | wc -l) -eq 0 ] ; then
  rm $OUT
fi
rm $1
```

### Apparmor

Unfortunately, I got an error on the first run.

```bash
$ tcpdump -ni enp6s0 -s1500 -C20 -w/tmp/ebscohost.pcap port 53 -z /tmp/dns_filter.sh
...
compress_savefile: execlp(/tmp/dns_filter.sh, /tmp/ebscohost.pcap) failed: Permission denied.
```

After double-checking file permissions, I looked in `/etc/apparmor.d/usr.sbin.tcpdump`:

```text
...

  # for -z
  /{usr/,}bin/gzip ixr,
  /{usr/,}bin/bzip2 ixr,

...
```

By default, this Debian installation only permits gzip to be run by
tcpdump.  I initially started adding my script (and all the binaries it
calls) to the list, but in the end opted to just change the apparmor
policy from "enforce" to "complain" for tcpdump:

```bash
$ sudo apt install apparmor-utils
...
$ sudo aa-complain /usr/sbin/tcpdump
Setting /usr/sbin/tcpdump to complain mode.
```

### Success

With all that done, we just need to run the capture and it will rotate
the file when it reaches the set size and run the filter script.  The filter
script uses `tshark` to filter out only queries/responses matching those
domains and deletes the original capture file.  It also removes its output
file if there were no matching records.

```bash
sudo tcpdump -ni enp6s0 -s1500 -C20 -w/tmp/ebscohost.pcap port 53 -z /tmp/dns_filter.sh &
```

After running for a while:

```bash
$ ls -l /tmp/ebscohost.*
-rw-r--r-- 1 root root     1392 Oct 28 10:25 /tmp/ebscohost.2021-10-28-10:25:30.pcap
-rw-r--r-- 1 root root     2056 Oct 28 11:21 /tmp/ebscohost.2021-10-28-11:21:53.pcap
-rw-r--r-- 1 root root     1688 Oct 28 12:46 /tmp/ebscohost.2021-10-28-12:46:01.pcap
-rw-r--r-- 1 root root      428 Oct 28 14:55 /tmp/ebscohost.2021-10-28-14:55:45.pcap
-rw-r--r-- 1 root root     2532 Oct 28 16:15 /tmp/ebscohost.2021-10-28-16:15:34.pcap
-rw-r--r-- 1 root root      424 Oct 28 16:25 /tmp/ebscohost.2021-10-28-16:25:18.pcap
-rw-r--r-- 1 root root 14643200 Oct 28 16:37 /tmp/ebscohost.pcap460
```

## Analysis

Now I have a bunch of individual capture files.  I can concatenate them
using `mergecap` from the wireshark package, copy the result to my local
machine and load it up in Wireshark.app for analysis.

```bash
mergecap -a -w nscache1-ebscohost.pcap -s1500 /tmp/ebscohost.*.pcap
```

I can filter out the NXDOMAIN responses by setting a display filter
`dns.flags.rcode == 3` or can just colorize them (so I can see them in
relation to the other traffic) by right-clicking on the "No such name"
line in one of the packet decodes, selecting "Colorize as Filter" and
choosing a color.

{{< figure src="wireshark-filter.png" align="center"
    caption="Setting a colorize filter in wireshark" >}}

## Conclusion

In less than a day of watching, we were able to get a capture of the DNS
response.  The provider acknowledged the problem, gave us a workaround
(a different subdomain to use), and is working on a more permanent
solution.

## A Better Approach

I posted this to twitter, and [@netresec](https://twitter.com/netresec)
responded with a comment suggesting another approach.

{{< tweet user="netresec" id="1454038986071191553" >}}

<!--
Nice solution! Would a oneliner like this have worked as well?
tcpdump -U -i enp6s0 -w - | tshark -r - -Y "dns.qry[.]name contains ebscohost"
-->

I had already tried something like this but dismissed it because when I
tried it the resulting `.pcap` files were truncated, causing data loss.
The output file was always an increment of 4k, so I assumed that this
was due to the way tcpdump buffered data when writing to the pipe.

{{< figure src="wireshark-truncated.png" align="center"
    caption="Wireshark error message" >}}

I didn't remember if I had tried the `-U` option, so I tried it again.
It worked perfectly on my macOS install (with stock `tcpdump` and
`wireshark`/`tshark` installed via [Homebrew][homebrew]), but failed as
before when I ran it on the actual server.

I spun up a few different docker containers to test and found that
Debian buster exhibits this problem, but bullseye works with the single
pipeline.  This is a much more elegant solution, which I will definitely
use in the future:

```bash
sudo tcpdump -U -ni enp6s0 -s1500 -w- port 53 | tshark -s1500 -w /tmp/ebscohost.pcap -r- -Y 'dns.qry.name ~ ebscohost.com or dns.qry.name ~ eislz.com'
```

I suspect it is an issue with the version of `tcpdump` or
`libpcap`. Rather than investigating further, I'll spend the time
planning and testing an OS upgrade of the servers.

{{< disclose open=true
    summary="For the record, these are the versions I tested:" >}}

<!-- markdownlint-disable MD033 -->
| OS Version      | App versions                                                                                                        | Works |
| ---             | ---                                                                                                                 | ---   |
| macOS 10.15.7   | tcpdump 4.9.3 -- Apple version 90.100.2 <br> libpcap 1.9.1 <br> TShark (Wireshark) 3.4.9 (v3.4.9-0-g365e236f5efe)   | Yes   |
| Debian buster   | tcpdump 4.9.3 <br> libpcap 1.8.1 <br> TShark (Wireshark) 2.6.20 (Git v2.6.20 packaged as 2.6.20-0+deb10u1)          | No    |
| Debian bullseye | tcpdump 4.99.0 <br> libpcap 1.10.0 (with TPACKET_V3) <br> TShark (Wireshark) 3.4.4 (Git v3.4.4 packaged as 3.4.4-1) | Yes   |
<!-- markdownlint-enable MD033 -->

{{< /disclose >}}

[homebrew]: https://brew.sh
