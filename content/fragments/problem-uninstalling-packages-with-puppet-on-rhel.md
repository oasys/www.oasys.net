---
title: "Problem uninstalling packages with puppet on RHEL"
date: 2021-05-05
tags:
  - redhat
  - puppet
  - rpm
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: How to deal with the "specifies multiple packages" error.
disableShare: false
disableHLJS: false
searchHidden: false

---

A [cow-orker][orking cows] came to me with a puppet issue today.  He was
trying to remove a package from a fleet of RedHat servers, using `ensure
=> absent` in the package resource, but it was failing:

```text
Error: Execution of '/bin/rpm -e firefox' returned 1: error: "firefox" specifies multiple packages:
  firefox-78.9.0-1.el7_9.x86_64
  firefox-78.9.0-1.el7_9.i686
Error: /Stage[main]/Profile::Base::Firefox/Package[firefox]/ensure: change from '78.9.0-1.el7_9' to 'absent' failed: Execution of '/bin/rpm -e firefox' returned 1: error: "firefox" specifies multiple packages:
  firefox-78.9.0-1.el7_9.x86_64
  firefox-78.9.0-1.el7_9.i686
```

A quick search showed that rpm has an `--allmatches` option.  From `rpm(8)`:

```text
--allmatches
       Remove all versions of the package which match PACKAGE_NAME.
       Normally an error is issued if PACKAGE_NAME matches multiple packages.
```

Since the [rpm provider][rpm] has the `uninstall_options` feature,
I suggested he add `uninstall_options => [ '--allmatches' ]` to the
[package][package] resource.  Unfortunately this failed, too.  Running a
debug showed that it was still just executing `rpm -e` and ignoring the
additional options.

Looking further, I see that the [yum provider][yum] is actually
the default on RedHat, and that it does _not_ support the
`uninstall_options` feature.

> yum
>
> Support via `yum`.
>
> Using this provider’s `uninstallable` feature will not remove
> dependent packages. To remove dependent packages with this provider
> use the `purgeable` feature, but note this feature is destructive and
> should be used with the utmost care.
>
> This provider supports the `install_options` attribute, which allows
> command-line flags to be passed to yum. These options should be
> specified as an array where each element is either a string or a hash.
>
> - Required binaries: `yum`, `rpm`
> - Default for: `osfamily` == `redhat`
> - Supported features: `install_options`, `installable`, `purgeable`,
> `uninstallable`, `upgradeable`, `versionable`, `virtual_packages`

Our second try was a success:

```puppet
package { 'firefox':
  ensure            => absent,
  provider          => 'rpm',
  uninstall_options => [ '--allmatches', '--nodeps' ],
}
```

[orking cows]: http://www.catb.org/jargon/html/C/cow-orker.html
[rpm]: https://github.com/puppetlabs/puppet/blob/main/lib/puppet/provider/package/rpm.rb#L12-L14
[yum]: https://puppet.com/docs/puppet/latest/types/package.html#package-provider-yum
[package]: https://puppet.com/docs/puppet/latest/types/package.html#package-attribute-uninstall_options
