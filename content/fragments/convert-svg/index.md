---
title: "Convert SVG files"
date: 2022-04-15
tags:
  - svg
  - omnigraffle
categories:
  - networking
showToc: false
draft: true
hidemeta: false
comments: false
description: |
  Workflow for importing SVG files into Omnigraffle
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "example.svg"
    alt: "Vector-based example SVG"
    caption: "[Vector-based example image](https://en.wikipedia.org/wiki/File:Vector-based_example.svg) licensed under [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/deed.en)"
    relative: true

---

I often want to use a third party logo or icon in one my
[OmniGraffle][omnigraffle] diagrams.  To avoid any [jaggies][jaggies]
with scaling raster images, I prefer to use a vector image format.
These are commonly [SVG][svg] files.

Unfortunately, current versions of OmniGraffle have limited SVG
import functionality.  (This is a known issue, and OmniGroup are
[working on it][ver7.7].)  A workflow I've found helpful in the
interim, is to convert the SVG file(s) to [EPS][eps], and drag
the resulting file into the document.

On macOS install `librsvg`, if it isn't already.  (It is a dependency
of `graphviz`, so it may already be installed.)

```text
brew install librsvg
```

The man page is very clear for other options, such as scaling or
converting to other formats, but for this use case just convert to EPS:

```text
rsvg-convert -f eps -o example.eps example.svg
```

To demonstrate, I grabbed the first example file I found online and
wasn't surprised to see that it does not import well into OmniGraffle.
In this case some of the gradients are the wrong place.  Converting the
file first to EPS, and then importing that into OmniGraffle gives a much
more workable image.  The size is a bit smaller by default, but that is
of no consequence for a vector drawing and can be easily scaled to the
correct size.

{{< figure src="example.svg" align="center"
    title="Original SVG file" >}}

{{< figure src="omnigraffle-svg-import.png" align="center"
    title="Imported SVG into OmniGraffle"
    caption="An example of Omnigraffle's poor SVG import function" >}}

{{< figure src="omnigraffle-eps-import.png" align="center"
    title="Imported EPS into OmniGraffle"
    caption="Perfect" >}}

[omnigraffle]: https://www.omnigroup.com/omnigraffle
[jaggies]: https://en.wikipedia.org/wiki/Jaggies
[svg]: https://developer.mozilla.org/en-US/docs/Web/SVG
[ver7.7]: https://www.omnigroup.com/releasenotes/omnigraffle/7.7
[eps]: https://en.wikipedia.org/wiki/Encapsulated_PostScript
