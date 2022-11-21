---
title: GitHub Enterprise Command-line Alias
date: 2022-11-20
tags:
  - GitHub Enterprise
  - git
  - github
  - yadm
  - hub
  - gh
categories:
  - Networking
showToc: false
draft: false
hidemeta: false
comments: false
description: |
  A bash alias/function to use GitHub Enterprise CLI commands
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "skyscraper.jpg"
    alt: "Skyscraper"
    caption: "[Skyscraper](https://pixabay.com/photos/architecture-skyscraper-2256489/) by [Michael Gaida](https://pixabay.com/users/652234-652234/) licensed under [CC0](https://creativecommons.org/publicdomain/zero/1.0/legalcode)"
    relative: true
---

To keep to my cli-workflow, I make regular use of the GitHub CLI
[tool](https://github.com/cli/cli), `gh` on the command line.

The [manual][gh-manual] specifies that you can specify the `GH_HOST`
environment variable to direct it to a GitHub Enterprise server, but
I don't want to have to type that in every time.  I added the following
to my `.bashrc`:

```bash
ghe() { GH_HOST="github.example.com" gh "$@"; }
complete -o default -F __start_gh ghe
```

Now, I can just run `gh` for public GitHub actions, and `ghe` for
anything to do with `example.com`'s server.

Since I also use [yadm][yadm] for managing my dotfiles, I have this
wrapped in a conditional check to only be used if this device is a work
machine:

```bash
if yadm config --get-all local.class | grep -q "work"; then
    ghe() { GH_HOST="github.example.com" gh "$@"; }
    complete -o default -F __start_gh ghe
    #...
fi
```

Before GitHub released their official cli tool, I regularly used [hub][hub].
I keep both installed, because sometimes my fingers are still in the habit
of using `hub`'s syntax.   If you're in the same situation, you can configure
hub to use a GitHub Enterprise server:

```bash
$ git config --global --add hub.host github.example.com
```

to add the following to your `~/.gitconfig`:

```ini
[hub]
    host = github.example.com
```

Add an entry for that host to your `~/.config/hub` file:

```yaml
github.example.com:
- user: jlavoie
  oauth_token: ghp_1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ
  protocol: https
```

And an alias in your `~/.bashrc`:

```bash
alias gite="GH_HOST=github.example.com hub"
```

[gh-manual]: https://cli.github.com/manual/
[yadm]: https://yadm.ioo
[hub]: https://hub.github.com
