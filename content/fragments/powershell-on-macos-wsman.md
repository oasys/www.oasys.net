---
title: "Powershell on macOS WSMan issue"
date: 2021-12-21
tags:
  - powershell
  - macos
  - openssl
  - homebrew
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: |
  A workaround to force powershell to user a modern version of openssl
disableShare: false
disableHLJS: false
searchHidden: false

---

There is an issue with the current build of powershell on macOS where
certain commands fail with the error `WSMan is either not installed or
unavailable for this system`.  Here's the command I was trying to run
when I first observed the issue:

```pwsh
PS /Users/jlavoie> Test-CsOnlineLisCivicAddress -CivicAddressId fb281cc9-eb22-4464-9bde-20b89ab3569d
New-PSSession: /Users/jlavoie/.local/share/powershell/Modules/MicrosoftTeams/3.0.0/netcoreapp3.1/exports/Test-CsOnlineLisCivicAddress.ps1:130
Line |
 130 |          $steppablePipeline.Process($_)
     |          ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | This parameter set requires WSMan, and no supported WSMan client
     | library was found. WSMan is either not installed or unavailable
     | for this system.
```

From a bit of research, it appears that it is because the packagers of
powershell have hardcoded the path to the openssl library to a specific
version in the homebrew directory.  Homebrew has (rightly so) removed
openssl1.0, so this breaks the tool.

```bash
$ otool -L /usr/local/microsoft/powershell/7/libmi.dylib
/usr/local/microsoft/powershell/7/libmi.dylib:
  @rpath/libmi.dylib (compatibility version 0.0.0, current version 0.0.0)
  /usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1238.60.2)
  /usr/lib/libpam.2.dylib (compatibility version 3.0.0, current version 3.0.0)
  /usr/local/opt/openssl/lib/libssl.1.0.0.dylib (compatibility version 1.0.0, current version 1.0.0)
  /usr/local/opt/openssl/lib/libcrypto.1.0.0.dylib (compatibility version 1.0.0, current version 1.0.0)
  /usr/lib/libz.1.dylib (compatibility version 1.0.0, current version 1.2.8)
```

[From what I can tell][issue-comment], Microsoft is aware of the issue
since over a year and a half ago, but has no estimate on when it will
be fixed.  I found a [bunch][1] [of][2] [other][3] reports of the same
issue.

Since installing a known-insecure version of openssl is a non-starter
for me, I used this workaround/fix to get everything working with a
modern openssl.

1. `pwsh -Command 'Install-Module -Name PSWSMan -Force'`
1. `sudo pwsh -Command 'Install-WSMan'`

You only need to do this once.  (Maybe again after powershell or openssl
upgrades, but I haven't confirmed that.)  Any subsequent powershell
sessions should now work.

You can see that it is now using the correct version of the openssl
shared library:

```bash
$ otool -L /usr/local/microsoft/powershell/7/libmi.dylib
/usr/local/microsoft/powershell/7/libmi.dylib:
  @rpath/libmi.dylib (compatibility version 0.0.0, current version 0.0.0)
  /usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1292.60.1)
  @loader_path/libssl.3.dylib (compatibility version 3.0.0, current version 3.0.0)
  @loader_path/libcrypto.3.dylib (compatibility version 3.0.0, current version 3.0.0)
  /usr/lib/libz.1.dylib (compatibility version 1.0.0, current version 1.2.11)
```

And the example command from above is now succeeding:

```pwsh
PS /Users/jlavoie> Test-CsOnlineLisCivicAddress -CivicAddressId fb281cc9-eb22-4464-9bde-20b89ab3569d

Result       Message CivicAddress
------       ------- ------------
AcceptedAsIs None    Microsoft.Rtc.Management.Hosted.Lis.Types.LacCivicAddress
```

[issue-comment]: https://github.com/PowerShell/PowerShell/issues/10600#issuecomment-610565488
[1]: https://talk.macpowerusers.com/t/powershell-7-wsman-issue/16615
[2]: https://github.com/Homebrew/homebrew-cask/issues/78085
[3]: https://www.matt-thornton.net/general/exchange-online-powershell-on-macos
