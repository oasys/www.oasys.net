---
title: "Git autoSetupRemote"
date: 2022-07-14
tags:
  - git
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: |
  An option to automatically set upstream on push for new branches
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "plane.jpg"
    alt: "Carpentry Plane"
    caption: "[Plane](https://pixabay.com/photos/brush-wood-tool-wood-carpentry-4536227/) by [enokenod](https://pixabay.com/users/enokenoc-8480545/) licensed under [CC0](https://creativecommons.org/publicdomain/zero/1.0/legalcode)"
    relative: true

---

I regularly read the git [blog][blog] and [release
notes][release-notes], but did not see mention of this new feature in
either.  I was pleasantly surprised when I saw this tweet from
James Ide:

{{< tweet user="JI" id="1546948817462800384" >}}

This may be minor as it saves only a few keystrokes.  (Less than it
seems, because `--set-upstream` can be abbreviated as `-u`.)  But, I do
it many times a day and almost always forget to do it the first time so
I bet its impact will be significant.  I see almost no reason not to do
`git config --global --add --bool push.autoSetupRemote true`.

The [git manual][manual] describes the option, and the use case is detailed
in the original [email][patch] and actual [commit][commit].

At the risk of repeating what James wrote, this is what happens
before the feature was implemented.

```bash
moonstone:~/www.oasys.net/(main=)$ git --version
git version 2.36.1
hub version refs/heads/master
moonstone:~/www.oasys.net/(main=)$ git cob testautoremote
Switched to a new branch 'testautoremote'
moonstone:~/www.oasys.net/(testautoremote)$ git push
fatal: The current branch testautoremote has no upstream branch.
To push the current branch and set the remote as upstream, use

    git push --set-upstream origin testautoremote

```

After running `brew update git`, `--set-upstream` is no longer needed,
and git does what is expected.

```bash
moonstone:~/www.oasys.net/(testautoremote)$ git --version
git version 2.37.0
hub version refs/heads/master
moonstone:~/www.oasys.net/(testautoremote)$ git push
Total 0 (delta 0), reused 0 (delta 0), pack-reused 0
remote:
remote: Create a pull request for 'testautoremote' on GitHub by visiting:
remote:      https://github.com/oasys/www.oasys.net/pull/new/testautoremote
remote:
To github.com:oasys/www.oasys.net.git
 * [new branch]      testautoremote -> testautoremote
branch 'testautoremote' set up to track 'origin/testautoremote'.
```

Here's the relevant section of `.gitconfig`:

```ini
[push]
        default = simple
        autoSetupRemote = true
```

[blog]: https://github.blog/2022-06-27-highlights-from-git-2-37/
[release-notes]: https://github.com/git/git/blob/v2.37.0/Documentation/RelNotes/2.37.0.txt
[manual]: https://git-scm.com/docs/git-config#Documentation/git-config.txt-pushautoSetupRemote
[patch]: https://lore.kernel.org/git/41c88e51ac6baf3ddaf08f2335015b4fa69fadf6.1651226207.git.gitgitgadget@gmail.com/
[commit]: https://github.com/git/git/commit/05d57750c66e4b58233787954c06b8f714bbee75
