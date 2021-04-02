---
title: "Iteration in Puppet"
date: 2021-04-02
tags:
  - puppet
  - hiera
categories:
  - networking
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: |
  Using puppet iteration to drive a data-first approach to managing resources.
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "cover.jpg"
    alt: "Galaxy"
    caption: "[galaxy](https://pixabay.com/photos/milky-way-universe-person-stars-1023340/) by [Free-Photos](https://pixabay.com/users/free-photos-242387/) licensed under [CC0](https://creativecommons.org/publicdomain/zero/1.0/legalcode)"
    relative: true

---

In the process of modernizing our [puppet][puppet] infrastructure, I've
been able to remove/delete many of the custom modules I had written
many years ago and use community developed and supported modules from
the [puppet forge][forge].  Many of these modules accommodate a pattern
of a single include in the manifest, and putting all the site-specific
configuration data (if any) in [hiera][hiera].

That said, [some](https://github.com/djjudas21/puppet-freeradius) don't allow this,
and resources must be explicitly configured.  In the past, we've used
[`create_resources`][create_resources] in combination with hiera lookups.

`freeradius.pp` profile:

```puppet
create_resources('freeradius::module', hiera('freeradius::modules', {}))
```

`radius.yaml` hiera data:

```yaml
freeradius::modules:
  ntlm_auth:     {}
  mschap:
    instances:
      - user
      - ma
  files:         {}
  ldap:
    servers:
...
```

Puppet version >4 now have [iteration functions][iteration] that make
this pattern more flexible to write and easier to read and understand
than the `create_resources` hack.  Using ideas from a [great blog
post][Iterating in Puppet], I would do something like:

```puppet
lookup('freeradius::modules', {}).each | String $name, Hash $properties | {
  freeradius::modules { $name: * => $properties }
}
```

Unfortunately, this particular module has a "generic" type
`freeradius::module` as well as a handful of more-specific defined
types, such as `freeradius::module::eap`.  I'd like to have a single yaml
hash control which ones of these resources were created.

I had to ask on the [puppet slack][slack] for a bit of help in the
syntax of interpolating a resource type's name, but quickly received a
couple pointers to help me along my way to a solution:

```puppet
include freeradius

lookup('freeradius::modules', {}).each | String $name, Hash $properties | {
  # use generic module type if more-specific one does not exist
  if defined(Resource["freeradius::module::${name}"]) {
    Resource["freeradius::module::${name}"] { $name: * => $properties }
  } else {
    freeradius::module { $name: * => $properties }
  }
}
```

Of course, I was admonished to be careful with `defined()` as its
behavior is critically related to how the catalog is processed.  [Getting
your Puppet Ducks in a Row][ducks] is a good explanation of these issues.
In this case, since the types are defined in the included `freeradius`
class module, I believe `defined()` will work as expected.

[puppet]: https://puppet.com
[forge]: https://forge.puppet.com
[hiera]: https://puppet.com/docs/puppet/latest/hiera_intro.html
[create_resources]: https://puppet.com/docs/puppet/latest/function.html#create_resources
[iteration]: https://puppet.com/docs/puppet/latest/lang_iteration.html
[slack]: https://slack.puppet.com
[Iterating in Puppet]: https://www.devco.net/archives/2015/12/16/iterating-in-puppet.php
[ducks]: http://puppet-on-the-edge.blogspot.com/2014/04/getting-your-puppet-ducks-in-row.html
