---
title: "Writing a vim syntax plugin"
date: 2021-02-23
tags:
  - vim
  - textfsm
categories:
  - networking
showToc: true
TocOpen: false
draft: false
hidemeta: false
comments: false
description: |
  Writing vim syntax plugin for TextFSM templates from scratch.
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "cisco_ios_show_cdp_neighbors_detail.textfsm.png"
    alt: "example TextFSM template with syntax highlighting"
    caption: "[example TextFSM template](https://github.com/networktocode/ntc-templates/blob/master/ntc_templates/templates/cisco_ios_show_cdp_neighbors.textfsm) with syntax highlighting"
    relative: true

---

## Motivation

I was creating a [TextFSM](https://github.com/google/textfsm) template,
and was disappointed with the lack of syntax highlighting support
for this filetype in my [favorite text editor](https://www.vim.org).
Typically, this is just a plugin away, but an exhaustive search turned
up nothing.  So, like all good geeks, I rolled up my sleeves and [made
one](https://github.com/oasys/vim-textfsm) myself.

## Process

Over the years, I have written little snippets in my `.vim/syntax/`
directory, or added some missing syntax to someone else's syntax
plugin, but had never written one from scratch.

The TextFSM language is quite simple, so it turned
out this was a very nice project for learning
about writing a syntax plugin.  The [text parsing
code](https://github.com/google/textfsm/blob/master/textfsm/parser.py)
was a bit difficult for me to read, honestly; but, the
[documentation](https://github.com/google/textfsm/wiki/TextFSM) was
thankfully very clear and understandable.

I also found [Andry Truett's
repo](https://github.com/andytruett/vscode-textFSM-syntax) for TextFSM
template syntax highlighting in Visual Studio Code, and used that as
inspiration.

## Plugin Layout

This is a simple plugin, so it only has a few files.

### Filetype detection

Filetype detection is based on filename extension, as defined in
`ftdetect/textfsm.vim`.

```vim
augroup textfsm
    autocmd!
    autocmd BufRead,BufNewFile *.textfsm set filetype=textfsm
augroup END
```

The `augroup` pattern with the `autocmd!` at the beginning allows
idempotency, so the plugin can be sourced/reloaded.

### Syntax

The whole syntax parsing exists in `syntax/textfsm.vim`.

We start by wrapping the begin and end of the file with:

```vim
if exists('b:current_syntax')
  finish
endif

"syntax highlighting code here

let b:current_syntax = 'textfsm'
```

This is a convention that prevents the file from loading when syntax highlighting
has already been enabled for this buffer.

Vim's `help syn-define` explains there are three types of syntax items:

1. keyword
2. match
3. region

We only use the latter two.  The basic difference between these is that
a match is a single match, while a region marks the "start" of a match,
which can potentially include (contain) other regions and matches inside
it.

In a TextFSM template, there are two types of blocks:

1. Value definitions (grouped at the beginning of the file), and
2. (one or more) State definitions and their associated Rules

#### Value Definitions

Value definitions are all on one line, and are prefixed with the work
"Value".  They are followed with an optional comma-separated list of
"Options", a variable name, and a regex.

```vim
" Value definition(s)
sy match  textfsmValue                  "\v^Value\s" nextgroup=textfsmOption,textfsmVar skipwhite
sy match  textfsmVar          contained "\v\S+" nextgroup=textfsmRegex skipwhite
sy match  textfsmOption       contained "\v<((Filldown|Key|Required|List|Fillup),?)+>" nextgroup=textfsmVar,textfsmRegex skipwhite
sy match  textfsmRegex        contained "\v\(.*\)"hs=s+1,he=e-1
```

The regex is surrounded by quotes.  The defined offsets, `hs=s+1,he=e-1`,
highlights only the regex between the quotes, not the quotes themselves.

#### State Blocks

State blocks with the state name at the beginning of the line, and is
followed by its associated Rules (and optional comments) indented below.

```vim
" State block(s)
sy match  textfsmState "\v^\w+\s*$" nextgroup=textfsmRule,textfsmStateComment skipnl
```

Comments within the State block are prefixed with a `#`:

```vim
sy match  textfsmStateComment contained "^\s*#.*" nextgroup=textfsmRule,textfsmStateComment skipnl
```

Rules are also followed by either more Rules or Comments.  Each Rule
itself begins with a regex starting with `^`. Any variables (in the
syntax `$VARNAME` or `${VARNAME}` is highlighted separately.

```vim
sy region textfsmRule         contained start="\v^\s\s?\^" end="$"  end="\s->" contains=textfsmRuleVar,textfsmArrow nextgroup=textfsmRule,textfsmStateComment skipnl skipwhite
sy match  textfsmRuleVar      contained "\v\$\w+"
sy match  textfsmRuleVar      contained "\v\$\{\w+\}"
```

Each rule may optionally be followed by an Action.  The action
is separated by the regex with an arrow (`->`). The individual
actions (`Next`, `Continue`, etc.) and the compound that make sense
(`Next.Record`, `Continue.Clear`, etc.) are well defined and expressed
in the regex.

```vim
sy match  textfsmArrow        contained "->" nextgroup=textfsmAction,textfsmNext skipwhite
sy match  textfsmNext         contained "\v\w+" skipnl
sy match  textfsmAction       contained "\v<(Next|Continue|Record|NoRecord|Clear(All)*)>" nextgroup=textfsmNext skipnl skipwhite
sy match  textfsmAction       contained "\v<(Next|Continue)\.(Record|NoRecord|Clear(All)*)>" nextgroup=textfsmNext skipnl skipwhite
```

There is also a special action called `Error`, followed by an optional
error message in quotes.

```vim
sy match  textfsmAction       contained "\v<Error>" nextgroup=textfsmErrMsg,textfsmRule skipnl skipwhite
sy match  textfsmErrMsg       contained "\v\".*\""hs=s+1,he=e-1 nextgroup=textfsmRule,textfsmErrMsg skipnl skipwhite
```

#### Comments

Comments in general are prefixed with a `#`:

```vim
sy match  textfsmComment "^\s*#.*"
```

Since syntax directives are "last match wins", this is kept at the
beginning of the file, so that it will not match comments in the State
blocks.

### Highlighting

Vim has a level of indirection between user-defined syntax groups and
the common highlight groups.  This permits independent naming of the
syntax groups and allows vim color schemes to interoperate.  See "Naming
Conventions" under `help highlight-groups` for the full list.  Here,
I linked the `testfsm*` syntax groups to the highlight groups that I
thought made the most sense.

```vim
hi def link textfsmValue PreProc
hi def link textfsmState Statement
hi def link textfsmNext Statement

hi def link textfsmAction Constant
hi def link textfsmOption Constant

hi def link textfsmVar Identifier
hi def link textfsmRuleVar Identifier

hi def link textfsmComment Comment
hi def link textfsmStateComment Comment
hi def link textfsmArrow Function

hi def link textfsmRule String
hi def link textfsmRegex String
hi def link textfsmErrMsg String
```

### Folding

The syntax file includes a "transparent" (not highlighted) region with
the "fold" argument so State blocks can be folded.

```vim
sy region textfsmStateFold start="\v^\S+\s*$" end="\v\n\s*\n" fold transparent
```

For the current buffer, set folding options (in `ftplugin/textfsm.vim`)
so that individual State blocks can be folded, but are displayed opened
by default.

```vim
setlocal foldmethod=syntax
setlocal foldlevel=1
```

### Development and Testing

During development, I'd often find a corner case that I wanted to be
able make sure were addressed.  To that end, I wrote a suite of unit tests
using [`vader.vim`](https://github.com/junegunn/vader.vim) to help
ensure no regressions would occur during development.

In addition to some simple tests to verify that the filetype and folding
were set correctly, syntax tests such as the following allowed me to
write assertions that the correct syntax group was matching at a given
cursor position.

```vim
Given textfsm (Multiple State Blocks):
  Value ONE (\S+)
  Value TWO (\S+)
  Value THREE (\S+)

  Start
    ^${ONE}\s+${TWO} -> AnotherState

  AnotherState
    ^${THREE}.*

Execute (syntax is good):
  AssertEqual SyntaxAt(5,1), 'textfsmState'
  AssertEqual SyntaxAt(6,3), 'textfsmRule'
  AssertEqual SyntaxAt(7,1), ''
  AssertEqual SyntaxAt(8,1), 'textfsmState'
  AssertEqual SyntaxAt(9,3), 'textfsmRule'
```

To test this interactively during development, it helped a lot to display
the current syntax group under the cursor in the status line.  I also bound
a key sequence to print out the asserts as I went.  This is included in `test/util.vim`:

```vim
" utility function and mapping to assist with generating syntax assertions

function! SyntaxItem()
  return synIDattr(synID(line('.'),col('.'),1),'name')
endfunction

function! GetSyn()
  let matchgroup=SyntaxItem()
  let row=getcurpos()[1]
  let col=getcurpos()[2]
  echom printf("  AssertEqual SyntaxAt(%d,%d), '%s'", row, col, matchgroup)
endfunction
```

## Resources

I found Steve Losh's book [Learn Vimscript the Hard
Way](https://learnvimscriptthehardway.stevelosh.com/) valuable in
getting started with writing a syntax plugin.  More advanced questions
were answered by vim's excellent help.

The TextFSM templates in the [Network to Code
repository](https://github.com/networktocode/ntc-templates) were a great
way to test my syntax parsing against different real-world data.  I
found many edge cases to tune the regexes, such as trailing whitespace,
using this method.

## Future

Most of the other syntax plugins I use also have an `Error` syntax
group, used to show syntax errors when nothing is matching the current
syntax grammar.  This requires full coverage, which I believe we have,
and would be nice to add.
