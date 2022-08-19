---
title: "Markdown line breaks"
date: 2022-08-18
tags:
  - markdown
  - pre-commit
  - git
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: |
  A tale of two trailing spaces
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "end-of-the-line.jpg"
    alt: "End of the Line"
    caption: "[End of the Line](https://pixabay.com/photos/line-end-path-train-railway-rails-4199271/) by [ivabalk](https://pixabay.com/users/ivabalk-782511/) licensed under [CC0](https://creativecommons.org/publicdomain/zero/1.0/legalcode)"
    relative: true

---

After using [Markdown][markdown] daily for many years, including all the
content in [this blog][blog], I learned there was another way to do line
breaks.

I had always thought that the only way to do was to either have a blank
line (which is *not* a line break, but a paragraph break) or add the
`<br />` HTML tag.  I avoided the latter because I think it just plain
looks ugly, and erases the elegance of using markdown, formatting
without tags.

Today, I learned that you can simply add two spaces at the end of the
line to force a line break.  When I first heard this, I thought it was
one of those newfangled extended markdown syntaxes.  That's not the
case, and [this syntax][line-break] is in John Gruber's original [syntax
documentation][syntax]:

> When you *do* want to insert a `<br />` break tag using Markdown, you
> end a line with two or more spaces, then type return.

I must've completely missed that every time I've read the document.

My elation at learning a new thing was quickly dashed when I remembered
that I hate trailing whitespace and use a `trailing-whitespace`
[pre-commit][pre-commit] hook on every repository I manage.  I like this
syntax feature so much that I started considering how I would add an
exception.  A quick look at the hook's [source code][exception] showed
that someone had already [thought][pr] of that:

```python
    # preserve trailing two-space for non-blank lines in markdown files
    if is_markdown and (not line.isspace()) and line.endswith(b'  '):
        return line[:-2].rstrip(chars) + b'  ' + eol
    return line.rstrip(chars) + eol
```

All I needed to do was add an argument to my `.pre-commit-config.yaml` file
for that particular hook:

```yaml
repos:
- repo: https://github.com/pre-commit/pre-commit-hooks
  rev: v4.3.0
  hooks:
  - id: trailing-whitespace
    exclude: .gitignore
    args:
    - --markdown-linebreak-ext=md
...
```

Now, trailing whitespace is still removed, except when it is used for forcing
line-breaks in markdown files.

[blog]: https://www.oasys.net/
[markdown]: https://daringfireball.net/projects/markdown/
[line-break]: https://daringfireball.net/projects/markdown/syntax#p
[syntax]: https://daringfireball.net/projects/markdown/syntax
[pre-commit]: https://pre-commit.com/
[exception]: https://github.com/pre-commit/pre-commit-hooks/blob/v4.3.0/pre_commit_hooks/trailing_whitespace_fixer.py#L38..L40
[pr]: https://github.com/pre-commit/pre-commit-hooks/pull/58
