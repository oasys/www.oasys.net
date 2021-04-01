---
title: "Cisco switch model changes after licensing"
date: 2021-03-22
tags:
  - cisco
  - licensing
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: |
  When the licensing is updated on certain Cisco switches, the reported
  model number also changes.
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "sticker.jpg"
    alt: "Cisco 3850 model number sticker"
    relative: true

---

When the licensing is updated on certain Cisco switches, the reported
model number also changes.  One of my coworkers ran into this issue
recently while trying to coordinate an RMA with TAC for a 3850 switch.
He replicated this in the lab and sent me some screenshots of his
terminal session to document what he saw.  I thought I'd share it here
to help others.

Out of the box, with the `ipbase` license, the switch shows up as an "-S" model.

!['show inventory' before](before.png)

This matches the physical sticker on the back of the unit.

![Photo of sticker highlighting model](sticker-model.jpg)

Then, he activated a different license, `ipservices`.

![Activate license](license.png)

With no other changes, the switch now reports that it is an "-E" model.

!['show inventory' after licensing](after.png)
