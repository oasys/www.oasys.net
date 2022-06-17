---
title: "Bash arrays"
date: 2022-06-16
tags:
  - bash
  - array
categories:
  - networking
showToc: false
draft: false
hidemeta: false
comments: false
description: |
  How indexed and associative arrays are used in bash,
  with examples.
disableShare: false
disableHLJS: false
searchHidden: false
cover:
    image: "ties.jpg"
    alt: "Silk Ties"
    caption: "[Silk Ties](https://pixabay.com/photos/silk-tie-sales-man-2846862/) by [ArtisticOperations](https://pixabay.com/users/artisticoperations-4161274/) licensed under [CC0](https://creativecommons.org/publicdomain/zero/1.0/legalcode)"
    relative: true

---

[Bash][bash] [arrays][array] are one dimensional variables.  They may be one of
two types, indexed or associative.  Indexed arrays have integer keys and
associative arrays have string keys.  Values for both are strings.

(Other languages call an associative array a "dictionary", "hash", or "map".)

[bash]: https://www.gnu.org/software/bash/
[array]: https://www.gnu.org/software/bash/manual/html_node/Arrays.html

## Initializing

Indexed arrays are declared using `declare -a`, but can also be
implicitly declared (in the global scope) using `ARRAY[subscript]`,
where `subscript` is an arithmetic expression.  For this reason,
associative arrays must be explicitly declared using `declare -A`.
Initial values may optionally be defined at declaration.  The `-p`
option to the `declare` builtin will print the full variable, including
type, keys, and values.

```bash
$ declare -a ARRAY                       # explicit declaration of indexed array
$ declare -A MAP                         # explicit declaration of associative array
$ ARRAY[10]=bar                          # implicit (global) declaration
$ declare -a ARRAY=([10]=foo [20]=bar)   # declare and set initial values
$ declare -a ARRAY=(foo bar)             # automatic indexes (starting at zero)
$ declare -A MAP=([foo]=bar [baz]=qux)   # declare and set initial values
$ declare -A MAP=(foo bar baz qux)       # alternate syntax
$ declare -p ARRAY
declare -a ARRAY=([0]="foo" [1]="bar")
$ declare -p MAP
declare -A MAP=([foo]="bar" [baz]="qux" )
```

## Retrieving

Individual values may be retrieved by referencing the variable with its
subscript in the form `${ARRAY[subscript]}`.  The braces are required.
All values may be retrieved by using `@` or `*` as the subscript.  All
keys may be retrieved by also prefixing the array name with a `!`.

```bash
$ echo ${!ARRAY[@]}                      # all keys
10 20
$ echo ${ARRAY[@]}                       # all values
foo bar
$ echo ${ARRAY[10]}                      # individual element
foo
$ echo ${ARRAY[10*2]}                    # subscript is a arithmetic expression
bar
```

```bash
$ echo ${!MAP[@]}                        # all keys
foo baz
$ echo ${MAP[@]}                         # all values
bar qux
$ echo ${MAP[baz]}                       # individual element
qux
```

If there is no element at the subscript, a null string (`""`) is
returned.  This is also the case when referencing all keys or values and
the array has no elements.

```bash
$ echo ${ARRAY[999]}

$ echo ${MAP[missing]}

$
```

When using `set -u` or `set nounset` to catch unset variables, these
will generate an error.  This can be avoided by adding a `-` to provide
a default value if undefined.

```bash
$ set -u
$ echo ${ARRAY[999]}
-bash: ARRAY[999]: unbound variable
$ echo ${MAP[missing]}
-bash: MAP[missing]: unbound variable
$ echo ${ARRAY[999]-}

$ echo ${MAP[missing]-}

$
```

Subscripts for indexed arrays are, by default, zero-based monotonically
increasing integers, but any integer may be used.  Negative subscripts
reference count back from the end of the array.

```bash
$ A=(first second third fourth)
$ echo ${A[1]}
second
$ echo ${A[-2]}
third
$ B=([10]=ten [20]=twenty [30]=thirty)
$ echo ${B[-11]}
twenty
```

## Length

Length is specified as `${#ARRAY[subscript]`.  Using a subscript of `@`
or `*` returns the number of elements in the array, otherwise the length
of that specific element of the array.

```bash
$ A=(first second third)
$ B=([10]=ten [20]=twenty [30]=thirty [40]=forty)
$ declare -A C=([one]=1 [two]=2)
$ echo ${#A[@]}
3
$ echo ${#B[@]}
4
$ echo ${#C[@]}                          # is the same with associative arrays
2
$ echo ${#B[40]}                         # "forty" is 5 characters long
5
```

## Setting

Elements may be added to an array individually by specifying the index.

```bash
$ B=([10]=ten [20]=twenty [30]=thirty)
$ B[40]=forty
$ echo ${B[@]}
ten twenty thirty forty
```

The `+=` operator appends to the existing list.

```bash
$ A=(first second)
$ A+=(third fourth)
$ echo ${A[@]}
first second third fourth
$ B=([10]=ten [20]=twenty)
$ B+=([30]=thirty [40]=forty)
$ echo ${B[@]}
ten twenty thirty forty
```

It is also possible to use the length as an index to add to the end of
the array.

```bash
$ A=(first second)
$ A[${#A[@]}]=third                      # difficult to read
$ echo ${A[@]}
first second third
```

Sometimes, simply using value expansion is most straightforward.

```bash
$ A=(first second)
$ B=(third fourth)
$ declare -a C=(${A[@]} ${B[@]} fifth)
$ echo ${C[@]}
first second third fourth fifth
```

## Deleting

The `unset` builtin can be used to delete individual elements or the
whole array.  A subscript of `@` or `*` or not specified at all will
delete the whole array, otherwise the specific element will be deleted.

```bash
$ declare -A MAP=([foo]=bar [baz]=qux)
$ echo ${MAP[@]}
bar qux
$ unset MAP[baz]                         # delete individual element
$ echo ${MAP[@]}
bar
$ unset MAP                              # delete whole array
$ echo ${MAP[@]}

$
```

## Interpolation

```bash
$ B=([10]=ten [20]=twenty [30]=thirty [100]=hundred)
$ key=10
$ echo ${B[$key]}
ten
$ echo ${B[key]}                         # arithmetic expression, $ not required
ten
$ echo ${B[key**2]}
hundred
```

```bash
$ declare -A MAP=([foo]=bar [baz]=qux)
$ key=baz
$ echo ${MAP[$key]}
qux
```

## Quoting

Quoting the subscript with single or double quotes is optional.

```bash
$ declare -A MAP
$ MAP[foo bar]=baz
$ MAP["foo bar"]=baz
$ MAP['foo bar']=baz
$ declare -p MAP
declare -A MAP=(["foo bar"]="baz" )
```

## Slicing

Indexed arrays can be can use slice notation `${ARRAY:start:length}` to
return a subset of the array. `start` is the index of the first element
to return and `length` is the count of elements to return.  If `length`
is unspecified all elements from the `start` to the end of the array are
returned.

```bash
$ A=(one two three four five six seven)
$ echo ${A[@]:2:3}
three four five
$ echo ${A[@]:5}
six seven
$ B=([10]=ten [20]=twenty [30]=thirty [40]=forty)
$ echo ${B[@]:20:2}
twenty thirty
```

## Looping

Often one wants to loop over all elements of an array.

```bash
$ B=([10]=ten [20]=twenty [30]=thirty [40]=forty)
$ for key in "${!B[@]}" ; do echo "$key is ${B[key]}" ; done
10 is ten
20 is twenty
30 is thirty
40 is forty
```
