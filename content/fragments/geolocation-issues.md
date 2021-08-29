---
title: "Geolocation issues"
date: 2021-08-27
tags:
  - geolocation
  - google
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: Google redirecting to their Hong Kong site
disableShare: false
disableHLJS: false
searchHidden: false

---

As I was getting ready to leave for a summer vacation, an emergency
call came from our service desk: "The Internet is in Chinese!"  After
a few back and forth questions, and a little bit of investigation, I
determined that Google had suddenly marked an entire /44 prefix as being
geolocated in Hong Kong.  When connecting to <https://www.google.com/>,
everyone was automatically redirected to <https://www.google.com.hk/>.

This only affected the IPv6 block.  The corresponding IPv4 block was
not affected.

I checked the major commercial geolocation providers, and they all
reported a (correct) US location for those addresses.  This [page][geo]
was very helpful in locating the sites to check.  At that point, I was
confident it was only Google that was affected.

[geo]: https://thebrotherswisp.com/index.php/geo-and-vpn/

I also noted that going to <https://www.google.com/ncr> disables this
redirect ("no country redirect"), and provided that to the service
desk as an interim workaround.

I reached out to an engineer at one of our upstreams that I know has a
direct peering relationship with Google.  They immediately opened a
ticket on our behalf and received the following response:

> Predicting user location from IP is known as IP Geolocation. Our
> systems detect whatever the location is updated through the ISP
> portal.
>
> If the issue do still persist you can do below. Thank You.
>
> If you would like to provide a Geolocation feed for the prefixes you
> originate, please provide an IP Geolocation feed on the ISP portal via
> Configuration > Data > IP Geolocation.
>
> <http://isp.google.com/geo_feed>
>
> Please be advised it can take up to 3 weeks for changes to update. If
> no update has been completed after this time, respond back to this
> thread for further follow up.

"Three weeks!"  We filled out the data.  There was a bunch more back
and forth, including a NOC engineer insisting it was a DNS issue.  (It
obviously wasn't.)  Eventually persistence paid off, and it was fixed.
I was very grateful to the engineer at our upstream for saving my
vacation.
