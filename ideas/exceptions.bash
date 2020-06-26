#!/bin/bash
:<<'```bash' [pardon the mess, this is an imperfect Bash-Markdown polyglot.][1]

Typed Exceptions with Stack Traces in Bash
==========================================

by Jeremy Banks, June 2020 ([hire me!])

With the typical error options enabled (`-euo pipefail`), unhandled errors in 
Bash scripts are propogated up the call stack until they're handled or exit the
script. However, the only associated information is the exit status code; less
than a byte of data. And if you want to handle different types of errors
separately, you may find yourself writing a lot of boilerplate. I'd like to 
present an alternative.

This is a proof-of-concept using aliases, traps, and functions to provide a
implementation of exception-style error handling in Bash, with `try-catch`
blocks and error "types".

```sh
function example-1 {
  try
    local contents=fread "$1"
  catch "IOError"
    echo "Are you sure entered that path correctly? $(caught)"
    exit 1
  yrt

  echo "The file named '$1' contained ${#contents} characters."
}

function fread {
  if [[ ! -f $1 ]]; then
    throw "IOError: the file '$1' does not exist"
  else
    cat "$1"
  fi
}
```

```
$ bash example-1 exists.txt
The file named 'exists.txt' contained 42 characters.
```

```
$ bash example-1 does-not.txt
Are you sure you entered that path correctly? IOError: the file 'does-not.txt' does not exist.
```

Unhandled errors will exit with a stack trace, whether they're `thrown` or not.

```sh
function example-2 {
  event-loop
}

function event-loop {
  while true; do
    tick
    sleep 1
  done
}

function tick {
  cat /bad/path
}
```

```
$ bash example-2
FatalError: Unhandled exception.

Traceback (most recent call last):
  File "example-2", line 42, in main
  File "example-2", line 2, in example-2
  File "example-2", line 8, in event_loop
  File "example-2", line 12, in tick
CalledProcessError1: command 'cat /bad/path/' returned non-zero exit status 1
```

This file provides a (hacky proof-of-concept) implementation of
"typed" "exceptions" with stack traces in Bash. This provides provides a
`try-catch-ryt` construct for catching exception, optionally with a given
"type" (message prefix), a `throw` function for explicitly raising exceptions,
and an `ERR` trap that automatically creates an exception (including stack
traces) for otherwise-unhandled errors.

Exceptions are just strings, and their "types" are just prefixes like 
"TypeError:". The exception throwing/catching state is stored in a global 
variable, and is propogated upwards through the call stack through Bash's
normal error handling, until it's handled like a normal error or by a
matching `try-catch-ryt` block.

Caveats
-------

This is probably a bad idea, don't hold me liable if you use it in
prod code. This implementation doesn't account for sub-shells; I think that
errors will still propogate fine, but the exception details will be lost,
however I haven't tested that. Try blocks only catch errors thrown from
functions that are called; if there's a `throw` directly inside the `try`
block, it won't be caught. Each `try` block can only have one `catch` block,
it can't have different ones for each type. Syntax errors are a mess.

Implementation in [exceptions.bash][2]
--------------------------------------

```bash
# Set a known-compatible version for the example.
# shellcheck disable=SC2034
readonly BASH_COMPAT=4.2

# Enable standard error checks.
set -euo pipefail

# Aliases are disabled by default in shell scripts, but this requires them.
shopt -s expand_aliases

# Returns the specified exit status, implicitly setting $?. Does nothing else.
# 
# Used to set the exit status of a block explicitly without returning or
# exiting from the enclosing function or subshell.
function ?= {
  return "${1?}"
}

# Enable __red__ if stdin is a terminal unless NO_COLOR is nonempty.
if [[ ${NO_COLOR:-} = "" ]] && tty > /dev/null; then
  function __red__ {
    printf "%s%s%s" "$(tput setaf 1 || :)" "$*" "$(tput sgr0 || :)"
  }
else
  function __red__ {
    printf "%s" "$*"
  }
fi

# We "throw" an exception by putting it in a global variable,
# then returning with a specific exit status. (TODO: attach full stack trace)
declare -g __THROWING__=""
declare -g __CATCHING__=""
alias throw='{ __THROWING__="$(cat -) [at $(caller 0)]"; return 69; } <<< '

# Our try-catch-yrt syntax wraps a block with a check for that status code
# being returned with __THROWING__ set. If so, the __catch_or_rethrow__ function
# is used to compare the __THROWING__ value to the caught prefix. If there's a
# match, the catch block is run the error is suppressed. If it doesn't match,
# the exception is re-thrown. If the try block exits with a non-zero exit
# status, but no exception it is normalized to an exit status of 1 (TODO:
# preserve instead?) and propogated.
alias try='if { '
alias catch=' } || [[ $? = 69 && $__THROWING__ ]]; then { __catch_or_rethrow__ '
alias yrt='}; else return 1; fi'
function __catch_or_rethrow__ {
  local exception_prefix="${1:-}"
  if ! [[ $__THROWING__ ]]; then
    echo "$(__red__ FatalError: __catch_or_rethrow__ called but nothing thrown)" >&2
    exit 1
  elif [[ $__THROWING__ == $exception_prefix* ]]; then
    __CATCHING__="$__THROWING__"
    __THROWING__=
    return 0
  else
    # re-throw
    return 69
  fi
}
# Use the $(caught) function to reference to the exception in a catch block.
function caught {
  if [[ $__CATCHING__ ]]; then
    printf "%s" "$__CATCHING__"
  else
    printf "RuntimeError: caught called outside of catch block"
  fi
}

:<<'```bash'
```

Examples in [exceptions.bash][2]
--------------------------------

```bash
function examples {
  try
    example_1
    example_2
    example_3
    example_4
  catch ""
    echo "$(__red__ FatalError: Unhandled exception: "$(caught)")"
    exit 1
  yrt
}

function example_1 {
  try
    format_percent "hello world"
  catch "RangeError"
    echo "Oh no, a value was out-of-range! Details: $(caught)"
  yrt
}

# Here's an example that throws different "types" of exceptions depending on
# the way the input is invalid.
#
# This function "formats" a percentage value (integer between 0 and 100) by
# printing it with a % character appended.
function format_percent {
  if [[ ${#@} != 1 ]]; then
    throw "ArgumentError: expected 1 argument, got: ${#@ }"
  fi
  if ! [[ $1 =~ ^[0-9]+$ ]]; then
    throw "TypeError: expected integer for argument 1, got: $1"
  fi
  if [[ $1 -lt 0 ]]; then
    throw "RangeError: argument 1 was too small, expected >= 0, got: $1"
  fi
  if [[ $1 -gt 100 ]]; then
    throw "RangeError: argument 1 was too large, expected <= 100, got: $1"
  fi
  
  echo "$1%"
}

function grandchild {
  format_percent 100
  format_percent 99
  format_percent 0
  format_percent 101
}

examples

:<<'<!-- -->'
```

To Do
-----

- capture full stack trace
- add colors
- Do we use the ERR hook to add this even for non-exceptions?
- add an exit hook displaying an uncaught stack trace
- concatenate stack traces if one error occurs while handling another
- make it look like python

Are you hiring? I'm looking!
----------------------------

I am currently looking for a new position as a software developer.

I have 8 years experience, including at Google and Stack Overflow. I've mostly
done full-stack web development (including TypeScript, Python, React, Django,
and some C# ASP.NET), with a recent focus in developer tools. I'd be happy to
do more of that, but would also be excited by an opportunity to work 
professionally with Rust, which I've used for some side projects but nothing
serious. I'm more interested in finding a good fit than a top salary.

I'm located in Toronto, Canada but would prefer a remote position.

Check out my profile on LinkedIn at <https://linkedin.com/in/jeremy-banks/>
or email me at <mailto:_@jeremy.ca> or <mailto:jeb@hey.com>.

<!-- link targets -->

 [1]: ./exceptions.txt
 [2]: ./exceptions.bash
 [examples]: #examples-in-exceptionsbash
 [hire me!]: #are-you-hiring-im-looking

<!-- -->
