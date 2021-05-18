---
title: "vim-go initializing gopls"
date: 2021-05-18T14:34:15-04:00
tags:
  - vim
  - go
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: How to reinstall deleted vim-go dependencies.
disableShare: false
disableHLJS: false
searchHidden: false

---

After some overly-aggressive cleaning of my `GOPATH`, vim "hung" with the message
"vim-go: initializing gopls" the next time I edited a `.go` file.

![initializing-gopls](initializing-gopls.png#center)

I discovered that running `:GoInstallBinaries` in vim would "fix" the
problem and re-install the missing packages.

```text
vim-go: fillstruct not found. Installing github.com/davidrjenni/reftools/cmd/fillstruct@master to folder /Users/jlavoie/go/bin/
vim-go: godef not found. Installing github.com/rogpeppe/godef@master to folder /Users/jlavoie/go/bin/
vim-go: motion not found. Installing github.com/fatih/motion@master to folder /Users/jlavoie/go/bin/
vim-go: errcheck not found. Installing github.com/kisielk/errcheck@master to folder /Users/jlavoie/go/bin/
vim-go: dlv not found. Installing github.com/go-delve/delve/cmd/dlv@master to folder /Users/jlavoie/go/bin/
vim-go: gorename not found. Installing golang.org/x/tools/cmd/gorename@master to folder /Users/jlavoie/go/bin/
vim-go: iferr not found. Installing github.com/koron/iferr@master to folder /Users/jlavoie/go/bin/
vim-go: golint not found. Installing golang.org/x/lint/golint@master to folder /Users/jlavoie/go/bin/
vim-go: gotags not found. Installing github.com/jstemmer/gotags@master to folder /Users/jlavoie/go/bin/
vim-go: impl not found. Installing github.com/josharian/impl@master to folder /Users/jlavoie/go/bin/
vim-go: goimports not found. Installing golang.org/x/tools/cmd/goimports@master to folder /Users/jlavoie/go/bin/
vim-go: golangci-lint not found. Installing github.com/golangci/golangci-lint/cmd/golangci-lint@master to folder /Users/jlavoie/go/bin/
vim-go: gomodifytags not found. Installing github.com/fatih/gomodifytags@master to folder /Users/jlavoie/go/bin/
vim-go: keyify not found. Installing honnef.co/go/tools/cmd/keyify@master to folder /Users/jlavoie/go/bin/
vim-go: staticcheck not found. Installing honnef.co/go/tools/cmd/staticcheck@latest to folder /Users/jlavoie/go/bin/
vim-go: asmfmt not found. Installing github.com/klauspost/asmfmt/cmd/asmfmt@master to folder /Users/jlavoie/go/bin/
vim-go: installing finished!
Press ENTER or type command to continue
```

Unless I'm missing something, go seems a bit lacking to me in its
package management tooling.  I don't see a good way to "clean up" unused
packages without removing dependencies from another package.
