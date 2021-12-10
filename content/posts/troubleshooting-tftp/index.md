---
title: "Troubleshooting TFTP"
date: 2021-12-09
tags:
  - tftp
  - cisco
  - wireshark
  - strace
  - tcpdump
  - fragmentation
  - copp
categories:
  - networking
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: |
  A story of troubleshooting TFTP failures on a 3850 switch
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "cover.jpg"
    alt: "Banana Pieces"
    caption: "[Banana](https://pixabay.com/photos/banana-fruit-manipulation-studio-2181470/) by [4924546](https://pixabay.com/users/4924546-4924546/) licensed under [CC0](https://creativecommons.org/publicdomain/zero/1.0/legalcode)"
    relative: true

---

Another engineer reported that "TFTP is not working" when he was trying
to stage firmware upgrades on our Cisco access network.  I offered to
help, and ended up spending a good portion of a day troubleshooting it.

## Replicate the Issue

Fortunately, we have lab gear that I could test this on without affecting
any production service.   I logged into a 3850 stack in the lab and successfully
transferred a test file from a TFTP server on a bastion host.

```bash
bastion:~$ echo "test data" | sudo tee /var/lib/tftpboot/test.txt
test data
```

```cisco
lab3850-sw-1#copy tftp://10.9.0.32/test.txt flash:
Destination filename [test.txt]?
Accessing tftp://10.9.0.32/test.txt...
Loading test.txt from 10.9.0.32 (via Vlan12): !
[OK - 10 bytes]

10 bytes copied in 0.072 secs (139 bytes/sec)
lab3850-sw-1#more flash:test.txt
test data

lab3850-sw-1#
```

That seemed to work fine.  So I tested something closer to the original
issue description.

```cisco
lab3850-sw-1#copy tftp://10.10.0.32/cat3k_caa-universalk9.16.06.09.SPA.bin flash:
Destination filename [cat3k_caa-universalk9.16.06.09.SPA.bin]?
Accessing tftp://10.10.0.32/cat3k_caa-universalk9.16.06.09.SPA.bin...
%Error opening tftp://10.10.0.32/cat3k_caa-universalk9.16.06.09.SPA.bin (Timed out)
```

It timed out.  From the output, it looks like the switch never receives
the first block.  I tried this a few times, and it consistently failed.
Having a repeatable test case makes troubleshooting _much_ easier!

## Look at the server

My first step at this point was to look at the server.  Was it sending
traffic?  From memory, UDP/69 is TFTP, so I got a packet capture on that.

```bash
bastion:~$ sudo tcpdump -ni any udp port 69 and host 10.12.254.1
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on any, link-type LINUX_SLL (Linux cooked), capture size 262144 bytes
20:14:28.664783 ethertype IPv4, IP 10.12.254.1.52292 > 10.9.0.32.69:  60 RRQ "cat3k_caa-universalk9.16.06.09.SPA.bin" octet blksize 8192
```

Well, there's the request!  But, the server isn't sending anything on
the network.  Is `tftpd` even running?  Looking at syslog:

```syslog
Dec  7 21:43:10 bastion in.tftpd[14149]: RRQ from 10.12.254.1 filename cat3k_caa-universalk9.16.06.09.SPA.bin
```

So, the server is running and sees the read request.  But why isn't it
sending the traffic to the client?  Since it isn't logging any more
information, I looked at what the process is doing (when it received the
request):

```bash
bastion:~$ sudo strace -f -e trace=network -p $(pidof in.tftpd)
strace: Process 14495 attached
setsockopt(4, SOL_IP, IP_PKTINFO, [1], 4) = 0
recvmsg(4, {msg_name={sa_family=AF_INET, sin_port=htons(54511), sin_addr=inet_addr("10.12.254.1")}, msg_namelen=28->16, msg_iov=[{iov_base="\0\1cat3k_caa-universalk9.16.06.09"..., iov_len=65468}], msg_iovlen=1, msg_control=[{cmsg_len=28, cmsg_level=SOL_IP, cmsg_type=IP_PKTINFO, cmsg_data={ipi_ifindex=if_nametoindex("enp8s0"), ipi_spec_dst=inet_addr("10.9.0.32"), ipi_addr=inet_addr("10.9.0.32")}}], msg_controllen=32, msg_flags=0}, 0) = 60
socket(AF_INET, SOCK_DGRAM, IPPROTO_IP) = 5
bind(5, {sa_family=AF_INET, sin_port=htons(0), sin_addr=inet_addr("10.9.0.32")}, 16) = 0
getsockname(5, {sa_family=AF_INET, sin_port=htons(35722), sin_addr=inet_addr("10.9.0.32")}, [16]) = 0
strace: Process 7884 attached
[...]
[pid  7884] socket(AF_UNIX, SOCK_STREAM, 0) = 6
[pid  7884] connect(6, {sa_family=AF_UNIX, sun_path="/var/lib/sss/pipes/nss"}, 110) = 0
[pid  7884] sendto(6, "\24\0\0\0\1\0\0\0\0\0\0\0\0\0\0\0", 16, MSG_NOSIGNAL, NULL, 0) = 16
[pid  7884] sendto(6, "\1\0\0\0", 4, MSG_NOSIGNAL, NULL, 0) = 4
[pid  7884] sendto(6, "\25\0\0\0&\0\0\0\0\0\0\0\0\0\0\0", 16, MSG_NOSIGNAL, NULL, 0) = 16
[pid  7884] sendto(6, "tftp\0", 5, MSG_NOSIGNAL, NULL, 0) = 5
[pid  7884] bind(4, {sa_family=AF_INET, sin_port=htons(0), sin_addr=inet_addr("10.9.0.32")}, 16) = 0
[pid  7884] connect(4, {sa_family=AF_INET, sin_port=htons(54511), sin_addr=inet_addr("10.12.254.1")}, 16) = 0
[pid  7884] setsockopt(4, SOL_IP, IP_MTU_DISCOVER, [0], 4) = 0
[pid  7884] sendto(4, "\0\6blksize\08192\0", 15, 0, NULL, 0) = 15
[pid  7884] recvfrom(4, "\0\4\0\0", 65468, 0, NULL, NULL) = 4
[pid  7884] sendto(4, "\0\3\0\1.IOSXE2.0\0\0\0\0\0\0\0\0\0\0\1\0\0\3\30\30J\232\333"..., 8196, 0, NULL, 0) = 8196
[pid  7884] sendto(4, "\0\3\0\1.IOSXE2.0\0\0\0\0\0\0\0\0\0\0\1\0\0\3\30\30J\232\333"..., 8196, 0, NULL, 0) = 8196
[...]
```

So, it _is_ `send`ing traffic!  But why am I not seeing it in
the capture?  Then I notice the `bind(4, {sa_family=AF_INET,
sin_port=htons(0), ...` -- this is the server assigning an ephemeral
port to the socket -- and realize that I completely forgot a fundamental
part of the TFTP protocol.  The UDP ports for the actual data transfer
are assigned by the client and server separately and are not just
on port 69.  A little chagrined, I repeat the test with an adjusted
`tcpdump` filter expression so I can see the data transfer packets:

```bash
bastion:~$ sudo tcpdump -ni any udp and host 10.12.254.1
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on any, link-type LINUX_SLL (Linux cooked), capture size 262144 bytes
20:42:02.146570 ethertype IPv4, IP 10.12.254.1.49665 > 10.9.0.32.69:  60 RRQ "cat3k_caa-universalk9.16.06.09.SPA.bin" octet blksize 8192
20:42:02.148933 IP 10.9.0.32.51851 > 10.12.254.1.49665: UDP, length 15
20:42:02.150504 ethertype IPv4, IP 10.12.254.1.49665 > 10.9.0.32.51851: UDP, length 4
20:42:02.150595 IP 10.9.0.32.51851 > 10.12.254.1.49665: UDP, bad length 8196 > 1472
20:42:02.150606 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:02.150618 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:02.150624 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:02.150629 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:02.150635 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:03.151739 IP 10.9.0.32.51851 > 10.12.254.1.49665: UDP, bad length 8196 > 1472
20:42:03.151756 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:03.151768 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:03.151773 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:03.151778 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:03.151784 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:05.153837 IP 10.9.0.32.51851 > 10.12.254.1.49665: UDP, bad length 8196 > 1472
20:42:05.153853 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:05.153864 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:05.153870 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:05.153875 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:05.153880 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:06.150506 ethertype IPv4, IP 10.12.254.1.49665 > 10.9.0.32.51851: UDP, length 4
20:42:09.156966 IP 10.9.0.32.51851 > 10.12.254.1.49665: UDP, bad length 8196 > 1472
20:42:09.156982 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:09.156994 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:09.156999 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:09.157005 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:09.157010 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:11.151369 ethertype IPv4, IP 10.12.254.1.49665 > 10.9.0.32.51851: UDP, length 4
20:42:17.151467 ethertype IPv4, IP 10.12.254.1.49665 > 10.9.0.32.51851: UDP, length 4
20:42:17.157132 IP 10.9.0.32.51851 > 10.12.254.1.49665: UDP, bad length 8196 > 1472
20:42:17.157147 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:17.157159 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:17.157165 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:17.157171 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:17.157176 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:24.152258 ethertype IPv4, IP 10.12.254.1.49665 > 10.9.0.32.51851: UDP, length 4
20:42:32.153083 ethertype IPv4, IP 10.12.254.1.49665 > 10.9.0.32.51851: UDP, length 4
20:42:33.158280 IP 10.9.0.32.51851 > 10.12.254.1.49665: UDP, bad length 8196 > 1472
20:42:33.158297 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:33.158312 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:33.158318 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:33.158324 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
20:42:33.158329 IP 10.9.0.32 > 10.12.254.1: ip-proto-17
```

Despite the diversion, I'm now confident that the server _is_ sending
the traffic to the switch.  By adding `-s1500 -w /tmp/labtftp.pcap` to
my capture and repeating the process, I can then load the capture into
wireshark and see if the protocol decode in more detail.

{{< figure src="tftp-server.png" align="center"
    caption="Packet capture from the TFTP server" >}}

I see that the server is repeatedly sending the same block to the TFTP
client.  Is something in the network between the server and client
dropping these packets?  Let's look at the other end and see if they're
actually getting there.

## Look at the client

The 3850 has the ability to do a packet capture of control-plane
traffic: `monitor capture <name> control-plane both`.  When I did this,
I saw the initial option acknowledgement response packet from the TFTP
server, but none of the data packets showed up in the capture.

Next, I enabled debugging for this traffic and alongside a capture.
This time, though, I did a _data-plane_ capture on the vlan (`12`) of
the trunk interface (`te1/1/3`) where I knew from the network topology
that the traffic from the server would be entering the switch:

```cisco
lab3850-sw-1#debug ip udp address 10.9.0.32
UDP packet debugging is on
lab3850-sw-1#mon cap tftp int te1/1/3 b vl 12 b
lab3850-sw-1#mon cap tftp m ipv4 host 10.9.0.32 any
lab3850-sw-1#mon cap tftp f l flash:tftp.pcap
lab3850-sw-1#mon cap tftp start
Started capture point : tftp
lab3850-sw-1#
Dec  7 20:41:56.377 UTC: %BUFCAP-6-ENABLE: Capture Point tftp enabled.
lab3850-sw-1#copy tftp://10.9.0.32/cat3k_caa-universalk9.16.06.09.SPA.bin flash:
Destination filename [cat3k_caa-universalk9.16.06.09.SPA.bin]?
Accessing tftp://10.9.0.32/cat3k_caa-universalk9.16.06.09.SPA.bin...
Dec  7 20:42:33.703:  UDP unique_ipport: using ephemeral max 55000
Dec  7 20:42:33.703: Reserved port 51337 in Transport Port Agent for UDP IP type 1
Dec  7 20:42:33.704: UDP: sent src=10.12.254.1(51337), dst=10.9.0.32(69), length=68
Dec  7 20:42:33.707: UDP: rcvd src=10.9.0.32(43234), dst=10.12.254.1(51337), length=23
Dec  7 20:42:33.708: UDP: sent src=10.12.254.1(51337), dst=10.9.0.32(43234), length=12
Dec  7 20:42:37.708: UDP: sent src=10.12.254.1(51337), dst=10.9.0.32(43234), length=12
Dec  7 20:42:42.709: UDP: sent src=10.12.254.1(51337), dst=10.9.0.32(43234), length=12
Dec  7 20:42:48.710: UDP: sent src=10.12.254.1(51337), dst=10.9.0.32(43234), length=12
Dec  7 20:42:55.710: UDP: sent src=10.12.254.1(51337), dst=10.9.0.32(43234), length=12
Dec  7 20:43:03.710: UDP: sent src=10.12.254.1(51337), dst=10.9.0.32(43234), length=12
%Error opening tftp://10.9.0.32/cat3k_caa-universalk9.16.06.09.SPA.bin (Timed out)
lab3850-sw-1#
Dec  7 20:43:11.712: Released port 51337 in Transport Port Agent for IP type 1
Dec  7 20:43:11.712: Released port 51337 in Transport Port Agent for IP type 1
lab3850-sw-1#mon cap tftp stop
```

The `debug ip` output confirms what I was seeing with the control-plane capture.
Let's look at the data-plane capture:

```cisco
lab3850-sw-1#sh mon cap f flash:tftp.pcap
Starting the packet display ........ Press Ctrl + Shift + 6 to exit

  1   0.000000    10.9.0.32 -> 10.12.254.1  UDP 64 43234 b^F^R 51337  Len=15
  2   0.002580    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=0, ID=165a)
  3   0.002621    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=1480, ID=165a)
  4   0.002650    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=2960, ID=165a)
  5   0.002712    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=4440, ID=165a)
  6   0.002740    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=5920, ID=165a)
  7   0.002770    10.9.0.32 -> 10.12.254.1  UDP 842 43234 b^F^R 51337  Len=8196
  8   1.002704    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=0, ID=1672)
  9   1.003005    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=1480, ID=1672)
 10   1.003715    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=2960, ID=1672)
 11   1.003799    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=4440, ID=1672)
 12   1.003841    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=5920, ID=1672)
 13   1.003874    10.9.0.32 -> 10.12.254.1  UDP 842 43234 b^F^R 51337  Len=8196
 14   3.005065    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=0, ID=181e)
 15   3.005115    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=1480, ID=181e)
 16   3.005832    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=2960, ID=181e)
 17   3.005889    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=4440, ID=181e)
 18   3.005922    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=5920, ID=181e)
 19   3.005966    10.9.0.32 -> 10.12.254.1  UDP 842 43234 b^F^R 51337  Len=8196
 20   7.008349    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=0, ID=18b1)
 21   7.008394    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=1480, ID=18b1)
 22   7.008427    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=2960, ID=18b1)
 23   7.009015    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=4440, ID=18b1)
 24   7.009072    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=5920, ID=18b1)
 25   7.009119    10.9.0.32 -> 10.12.254.1  UDP 842 43234 b^F^R 51337  Len=8196
 26  15.008350    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=0, ID=1f42)
 27  15.008401    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=1480, ID=1f42)
 28  15.009175    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=2960, ID=1f42)
 29  15.009232    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=4440, ID=1f42)
 30  15.009266    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=5920, ID=1f42)
 31  15.009311    10.9.0.32 -> 10.12.254.1  UDP 842 43234 b^F^R 51337  Len=8196
 32  31.009588    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=0, ID=22c9)
 33  31.009639    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=1480, ID=22c9)
 34  31.009868    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=2960, ID=22c9)
 35  31.010410    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=4440, ID=22c9)
 36  31.010465    10.9.0.32 -> 10.12.254.1  IPv4 1518 Fragmented IP protocol (proto=UDP 17, off=5920, ID=22c9)
 37  31.010512    10.9.0.32 -> 10.12.254.1  UDP 842 43234 b^F^R 51337  Len=8196

lab3850-sw-1#
```

This matches exactly what the capture on the TFTP server was showing.
I can copy the `pcap` file off the switch and load it up in Wireshark
to compare the two captures side-by-side to convince myself of this.
Now I can reasonably assume that there is nothing between the server
and the client causing problems -- packets are getting to the switch,
but something in the switch is causing them _not_ to get to the control
plane.

{{< figure src="tftp-switch-trunk.png" align="center"
    caption="Packet capture from the TFTP client" >}}

## Fragmentation

I do notice that _one_ packet, the option response from the server, _did_
make it to the control plane, as it is show by the `debug ip` output:

```syslog
Dec  7 20:42:33.707: UDP: rcvd src=10.9.0.32(43234), dst=10.12.254.1(51337), length=23
```

What is different about that one option acknowledgement packet that
_did_ get through and the (many) data transfer packets that somehow got
dropped?  The first thing I notice is that the data transfer packets are
fragmented.

First, let's understand why there is fragmentation in the first place.
TFTP is a quite simple protocol, designed to be implemented very few
lines of code such as in a bootrom of a device.  It has a simple "send
block", "ack block", "send next block", etc. pacing.  As latency and/or
file size increases, transfer speed plummets.

As a way of addressing this issue, [RFC2347][rfc2437] specifies an
extension to the protocol to allow negotiation of larger block sizes.
When a block is sent that is larger than the interface MTU -- in this
case, 1500 bytes -- the packet is fragmented.  It should be reassembled
by the client networking stack once it receives all the packets.

This option can be seen in the capture as well as in the `blksize 8192`
at the end of the TFTP server's syslog entry for the request.  Both the
server and client are configured to support this, so the data transfer
will end up fragmenting packets if the file is larger than a single
MTU.  This would also explain why my original test file of just a few
bytes worked, but a full firmware image failed.

### Adjust server

Looking at the my choices on the server side, `man tftp` shows:

```man
RFC 2347 OPTION NEGOTIATION
       This  version  of tftpd supports RFC 2347 option negotiation.  Currently implemented
       options are:

       blksize (RFC 2348)
              Set the transfer block size to anything less than or equal to the  specified
              option.  This version of tftpd can support any block size up to the theoret-
              ical maximum of 65464 bytes.

[...]

       The --refuse option can be used to disable specific options; this may be  necessary
       to  work  around  bugs  in specific TFTP client implementations.  For example, some
       TFTP clients have been found to request the blksize option, but crash with an error
       if they actually get the option accepted by the server.
```

I temporarily added `--refuse blksize` to the TFTP server's options
(`TFTP_OPTIONS` in `/etc/default/tftpd-hpa` on Debian systems) to
disable block size negotiation, and re-tested the transfer.  It
succeeded!

[rfc2437]: https://datatracker.ietf.org/doc/html/rfc2347

### Adjust client

Since the server-side change would affect all clients, I didn't want to
just leave it this way.  So, I looked for a way to adjust the client
behavior on the switch.  A Google search for "3850 tftp block size"
turned up a Cisco [technote][technote] claiming "the Catalyst 3850 uses
a [default] TFTP block size value of 512, which is the lowest possible
value" and recommends setting `ip tftp blocksize 8192` to "speed up the
transfer process."

Obviously the technote information is old (2015) and incorrect, but it
gave me the information I needed to change the setting.  The current
default appears to be 8192.  By changing to a smaller block size, we
avoid fragmentation and transfers now work.

```cisco
lab3850-sw-1#sh run | i blocksize
lab3850-sw-1#sh run all | i blocksize
ip tftp blocksize 8192
lab3850-sw-1#conf t
Enter configuration commands, one per line.  End with CNTL/Z.
lab3850-sw-1(config)#ip tftp blocksize 1468
lab3850-sw-1(config)#end
```

[technote]: https://www.cisco.com/c/en/us/support/docs/wireless/5760-wireless-lan-controller/117636-technote-tftpfile-00.html

### Contact TAC

I'm happy for now with this workaround, as it only modifies the affected
devices.  I'd still like better resolution, though.

I spent some time isolating the issue to a particular IOS-XE version,
16.06.07.  With this information, my troubleshooting notes, and packet
captures I opened a TAC case.  Within a day, this was matched with a
[bugid][CSCvq01204]:

> Symptom:
>
> An IOS-XE based C3K switches are not able to receive a file copy from
> a TFTP server when TFTP blocksize is set to 8192.
>
> Conditions:
>
> Catalyst 3K running on 16.6.6 code. Whether DHCP snooping is enabled
> globally or not does not affect the test result. This issue is not
> CSCvk53444.
>
> Workaround:
>
> If TFTP blocksize value is 1468 or lower, transmission works.

Unfortunately, it also notes "Known Fixed Releases (0)".  I'm awaiting feedback
from the TAC engineer on if/when we can expect a fix.

[CSCvq01204]: https://bst.cloudapps.cisco.com/bugsearch/bug/CSCvq01204

## Not quite fixed

After testing this workaround a handful of times and observing that
all transfers succeeded, I responded to the reporting engineer with my
findings, recommended setting the block size to 1468 and re-trying.
They came back a short while later saying "It helped, but I'm still
seeing intermittent timeouts."

I was a bit baffled.  I thought I had solved it.  I had a consistent test
case that failed every time, a plausible workaround validated by TAC that
when applied, made my test case succeed every time I tested it.  Time to
get back to troubleshooting!

### Attempt to replicate again

I noted the new qualifier of "intermittent" in the failure description.
I decided to write a little script to repeatedly test the TFTP transfer
to see if it would eventually fail.  After less than an hour, I captured
a failure:

```cisco
lab3850-sw-1#copy tftp://10.10.0.32/cat3k_caa-universalk9.16.06.09.SPA.bin null:
Accessing tftp://10.9.0.32/cat3k_caa-universalk9.16.06.09.SPA.bin...
Loading cat3k_caa-universalk9.16.06.09.SPA.bin from 10.9.0.32 (via Vlan13): !!!!!!!!!!!!!!!!!!!!!!!!!... [timed out]
%Error reading tftp://10.9.0.32/cat3k_caa-universalk9.16.06.09.SPA.bin (Connection timed out)
```

This is different than the previous timeout.  This one actually
succeeded in transferring a couple dozen blocks and _then_ it timed out.

### Check CoPP

My first guess at this point was maybe it was control plane policing
dropping the traffic to the CPU in times of load.  That could explain
the intermittent nature of the symptom.  Unfortunately, I know a lot
about NXOS CoPP, but very little about how it is implemented or even
configured on the 3850 platform.  Despite being an early adopter of the
3850, I've just used the default policy since that feature was added.

After reading Cisco's [configuration guide][configuration-copp] for CoPP
on the 3850 platform, I came away with the following understanding of
its limitations:

- The built-in policy-map, `system-cpp-policy`, and the pre-defined
  classes cannot be modified.
- The conform and exceed actions in each of the classes cannot be
  modified by the user.
- The only policing available is based on packets per second (pps)

Additionally:

- Each policing rate has a default pps for that class
- This rate can be deleted entirely (no policing for that class)
- Or, the rate can be adjusted (a different pps rate for that class)

Most critically, though, were the commands to check drop statistics on the switch:

```cisco
lab3850-sw-1#show platform hardware fed switch active qos queue stats internal cpu policer

                         CPU Queue Statistics
============================================================================================
                                              (default)  (set)     Queue
QId PlcIdx  Queue Name                Enabled   Rate     Rate      Drop(Bytes)
-----------------------------------------------------------------------------
0    11     DOT1X Auth                  Yes     1000      1000     0
1    1      L2 Control                  Yes     2000      2000     0
2    14     Forus traffic               Yes     1000      1000     678312
3    0      ICMP GEN                    Yes     600       600      0
4    2      Routing Control             Yes     5400      5400     0
5    14     Forus Address resolution    Yes     1000      1000     0
6    0      ICMP Redirect               Yes     600       600      0
[...]
```

I note that this one queue is exceeding its configured rate and dropping packets.

```cisco
lab3850-sw-1#sh policy-map control-plane input class system-cpp-police-forus
 Control Plane

  Service-policy input: system-cpp-policy

    Class-map: system-cpp-police-forus (match-any)
      0 packets, 0 bytes
      5 minute offered rate 0000 bps, drop rate 0000 bps
      Match: none
      police:
          rate 1000 pps, burst 244 packets
        conformed 438547323 bytes; actions:
          transmit
        exceeded 678312 bytes; actions:
          drop
```

[confguring-copp]: https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst3850/software/release/16-1/configuration_guide/b_161_consolidated_3850_cg/b_161_consolidated_3850_cg_chapter_01011101.html

### Disable policing entirely

To quickly verify this theory, I completely disabled policing for that
particular class:

```cisco
lab3850-sw-1#conf t
Enter configuration commands, one per line. End with CNTL/Z.
lab3850-sw-1(config)#policy-map system-cpp-policy
lab3850-sw-1(config-pmap)#class system-cpp-police-forus
lab3850-sw-1(config-pmap-c)#no police rate 100 pps
lab3850-sw-1(config-pmap-c)#end
lab3850-sw-1#sh policy-map control-plane input class system-cpp-police-forus
Control Plane
 Service-policy input: system-cpp-policy
 Class-map: system-cpp-police-forus (match-any)
0 packets, 0 bytes
5 minute offered rate 0000 bps
Match: none
```

Then, I repeated the looped file transfers and did not see any failures
after a couple hours of trying.  This isn't completely conclusive,
but I'm hopeful that I've found a viable solution.  I know we have
been recently doing evaluation testing of some monitoring tools that
may use some aggressive SNMP polling ([Statseeker][statseeker] and
[AKIPS][akips]) that may be contributing to the additional load.

Before I proceeded, I made sure to return the CoPP to defaults, so that
policing would be re-enabled on that class:

```cisco
lab3850-sw-1#conf t
Enter configuration commands, one per line.  End with CNTL/Z.
lab3850-sw-1(config)#cpp sys
lab3850-sw-1(config)#cpp system-default
 Policer rate for all classes will be set to their defaults
lab3850-sw-1(config)#end
```

[statseeker]: https://statseeker.technichegroup.com
[akips]: https://www.akips.com

### Increase policing rate

At this point, it makes sense to find a new policing rate that will work
in our environment.  But what should that be?  I look at the release
notes for mentions of CoPP-related changes, I see that in 16.8.1a there
was a note:

> The default rate for all the CPU queues under
> `system-cpp-police-forus` was increased to 4000.

The rate in the current version we're running is 1000 pps.  Cisco seems
to think adjusting this to 4000 is reasonable, so I do the same.

```cisco
lab3850-sw-1#conf t
Enter configuration commands, one per line.  End with CNTL/Z.
lab3850-sw-1(config)#policy-map system-cpp-policy
lab3850-sw-1(config-pmap)#class system-cpp-police-forus
lab3850-sw-1(config-pmap-c)#police rate 4000 pps
lab3850-sw-1(config-pmap-c-police)#end
lab3850-sw-1#sh policy-map control-plane input class system-cpp-police-forus
 Control Plane

  Service-policy input: system-cpp-policy

    Class-map: system-cpp-police-forus (match-any)
      0 packets, 0 bytes
      5 minute offered rate 0000 bps, drop rate 0000 bps
      Match: none
      police:
          rate 4000 pps, burst 976 packets
        conformed 393818753 bytes; actions:
          transmit
        exceeded 673948 bytes; actions:
          drop
```

After another round of (successful) testing, I recommend to the
reporting engineer that they make these adjustments to the CoPP policy
on these switches and reattempt the transfers.  They report no issues
across 500+ switches.

## Conclusion

This was a fun troubleshooting exercise into some technologies we often
take for granted.  I was reminded of a few tenets of troubleshooting:

### Get an accurate description of the issue

Make sure you collect as much information as possible about the issue.
Data points about when it occurs, when it _does not_ occur, when it was
first noticed, and any related error messages or odd outputs.  If the
person reporting has already performed troubleshooting steps, take notes
about those and the results -- but be wary of counting on them unless
you've independently verified the steps yourself.

### Replicate

If at all possible, find a repeatable way to replicate the issue.
Having a test you can perform to replicate the problem will permit you
prove or disprove different theories about what may be causing the
issue.  Once you (think that you) have a fix, you can use this test to
verify it.

### Lab

If you can, recreate the problem in an isolated environment.  This
allows you to make changes to the environment without worrying about how
it affects production services.  Either Once the problem is recreated,
you can begin to isolate the issue by adding or removing related
components.

### Understand the protocols

Make sure you understand how the protocols in question will behave on
the network.  Verify that understanding by observing those protocols in
an environment where things are working as expected.

### Be wary

Don't declare success too early.  As in this situation, there may
be multiple contributing factors.  It isn't uncommon that a bug or
misconfiguration goes unnoticed until some other change (or changes!)
combines with it to cause an issue.

### Take comprehensive notes

Write down or log every step.  When you're stuck, go back and review
your notes and your decision log.  You may discover logic errors or gaps
in your testing.  Sometimes, something data you collect early in the
process may be the key, but that is not evident until it is looked at
in the light of information gathered much later.  Sometimes you spend
a lot of time and effort going down a dead end; your notes will help
you retrace your steps and start working on a different branch in the
decision tree.

### Take a break

Lastly, when you're stuck on a problem, let your mind rest.  Go for a
walk, get a cup of coffee/tea, meditate.  Trust your unconscious mind to
keep working the issue; you will often be surprised that a few minutes
of quiet time will sometimes surface great insights or new approaches.
