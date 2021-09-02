---
title: "Leading zeros in bash"
date: 2021-09-01
tags:
  - bash
categories:
  - networking
  - dns
showToc: false
draft: false
hidemeta: false
comments: false
description: fixing a bug in a bash script
disableShare: false
disableHLJS: false
searchHidden: false
---

A team member reported a problem with pre-commit hook I wrote,
[`check-dns-serial`][check-dns-serial], which ensures the SOA serial
number is updated on any modified zone files.  The script was giving
them an error when they made a commit after the 8th revision in a day.

It was an interesting bug in a bash script that I thought might be
helpful to share.  The serial number is, by convention, stored as a date
string plus a 2-digit revision number.  For example, `2021090104` would
be today's 4th change.  This allows for 99 changes a day.  The script
splits this string (using `cut`) into two variables, the date and the
revision.  At one point, it checks to see if the old revision is already
99, to avoid an overflow.  This is line that threw the error:

```bash
if [[ "$old_rev" -eq 99 ]]; then
```

Can you spot the problem?

Bash will interpret numbers with a leading zero as an octal number.  So,
`08 -eq 99` doesn't make sense as there are no 8's in octal.

From "ARITHMETIC EVALUATION" in `bash(1)`:

> Constants with a leading 0 are interpreted as octal numbers.  A
> leading 0x or 0X denotes hexadecimal.  Otherwise, numbers take the
> form [base#]n, where the optional base is a decimal number between 2
> and 64 representing the arithmetic base, and n is a number in that
> base.  If base# is omitted, then base 10 is used.  When specifying n,
> the digits greater than 9 are represented by the lowercase letters,
> the uppercase letters, @, and _, in that order.  If base is less
> than or equal to 36, lowercase and uppercase letters may be used
> interchangeably to represent numbers between 10 and 35.

I ported this logic from a [very old bash script][dns-increment] that
piped the math, incrementing a number, to `bc`.  Since modern bash can
do that arithmetic itself, I changed it to remove the dependency.  But,
I didn't think about this possible failure mode.

```bash
sapphire:~$ echo $((08 + 9))
-bash: 08: value too great for base (error token is "08")
sapphire:~$ echo $((10#08 + 9))
17
```

The [fix][diff] was relatively simple.  As you see in the man page, you can
force the base by specifying `base#` before the variable.

```diff
diff --git a/hooks/check-dns-serial.sh b/hooks/check-dns-serial.sh
index 4a198c7..2fa7d5f 100755
--- a/hooks/check-dns-serial.sh
+++ b/hooks/check-dns-serial.sh
@@ -66,11 +66,11 @@ for file in $(git diff --staged --name-only --diff-filter=M); do
     if [[ "$date" -gt "$old_date" ]]; then
       serial="${date}00"
     elif [[ "$date" -eq "$old_date" ]]; then
-      if [[ "$old_rev" -eq 99 ]]; then
+      if [[ "10#$old_rev" -eq 99 ]]; then
         echo "    too many revisions for today to increment \"$old_serial\"."
         continue
       fi
-      serial="${date}$(printf "%02d" $((old_rev + 1)))"
+      serial="${date}$(printf "%02d" $(("10#$old_rev" + 1)))"
     else
       echo "    current serial \"$old_serial\" is in the future, not updating."
       continue
```

[check-dns-serial]: https://github.com/bowdoincollege/noc-commit-hooks/blob/master/hooks/check-dns-serial.sh
[dns-increment]: https://github.com/slaught/enki_cloud/blob/master/scripts/scripts/dns-increment
[diff]: https://github.com/bowdoincollege/noc-commit-hooks/commit/559b27b7111c877f1dc781bf8e84c1495752a733#diff-f2cf5079db4c08923f95b519db529579b6380b813e7834d3819082aa75e1407b
