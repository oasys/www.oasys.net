---
title: "How to Identify private MAC addresses"
date: 2022-03-09
tags:
  - networking
  - troubleshooting
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: |
  With recent implementations of MAC randomization, it is
  handy to be able to identify these addresses at a glance.
disableShare: false
disableHLJS: false
searchHidden: false

---

While troubleshooting a wireless issue, I mentioned offhand to another
engineer that a particular [MAC address][mac] was private.  They
immediately asked me "How did you know just by looking at it?"

I said "Look at the second least significant bit of the most significant
byte," but quickly realized that needed a bit more explanation.

"Private" MAC addresses, at least as implemented by [Apple][apple]
and [Android][android], sets the locally-administered bit for their
randomized addresses.  [RFC7042][rfc7042] section 2.1 specifies the
"Local bit":

> The Local bit is zero for globally unique EUI-48 identifiers assigned
> by the owner of an OUI or owner of a longer prefix.  If the Local
> bit is a one, the identifier has been considered by IEEE 802 to be a
> local identifier under the control of the local network administrator
> [...]

This is the `02` bit of the first octet in the MAC.  If it is set, this
is a locally-administered address.  Essentially, if the second hex digit
is `2`, `6`, `A`, or `E`, it is a private MAC.

- x**2**:xx:xx:xx:xx:xx
- x**6**:xx:xx:xx:xx:xx
- x**A**:xx:xx:xx:xx:xx
- x**E**:xx:xx:xx:xx:xx

What about MAC addresses with the next bit set, such as when the first
octet is `03` or `07`?  Those still have the local bit set.  Yes,
but the `01` bit is the unicast/multicast bit (individual/group, I/G
bit).  We [seldom][rfc2464] see use of locally-administered multicast
layer 2 addresses, so can be ignored for the purposes of "private MAC
addresses".

[mac]: https://en.wikipedia.org/wiki/MAC_address
[apple]: https://support.apple.com/en-us/HT211227
[android]: https://source.android.com/devices/tech/connect/wifi-mac-randomization
[rfc7042]: https://www.rfc-editor.org/rfc/rfc7042.html#section-2.1
[rfc2464]: https://www.rfc-editor.org/rfc/rfc2464.html#section-7
