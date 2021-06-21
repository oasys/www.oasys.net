---
title: "Using docker to compile a binary"
date: 2021-06-21T10:51:34-04:00
tags:
  - docker
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: Workflow to spin up a quick compile host
disableShare: false
disableHLJS: false
searchHidden: false

---

Sometimes I have to compile a binary or build a custom package on an
old platform or an operating system where I don't have a compile host
available.  Docker is a perfect tool for this type of ad-hoc workflow.

```bash
docker run --rm -it -v $(pwd):/mnt ubuntu:bionic
sed -i 's/^# deb-src/deb-src/' /etc/apt/sources.list
apt-get update
apt-get -y install dpkg-dev libssl-dev # any other dependencies
cd
apt-get source source-package-here
# cd into package and compile/make/build/etc
strip resulting_binary
cp resulting_binary /mnt
exit
```

This mounts the current directory at the `/mnt` mount point in the
container.  The resulting artifacts (binaries, packages, etc.) can be
preserved by copying them out of the container before exiting.
