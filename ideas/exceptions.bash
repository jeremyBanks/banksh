#!/bin/bash
:<<'```bash' [pardon the mess, this is an imperfect Bash-Markdown polyglot.][1]

Typed Exceptions with Stack Traces in Bash
==========================================

by Jeremy Banks, July 2020 ([hire me!])

With the typical `-euo pipefail` error options enabled, unhandled errors in 
Bash scripts are propagated up the call stack until they're handled or exit the
script (see [details below][A1] if you're unfamiliar). However, the only 
associated data is the exit status code: less than a byte of information. If
you want to handle different types of errors separately, you may find yourself
writing a lot of boilerplate. I'd like to present an alternative.

This is a proof-of-concept using aliases, traps, and functions to provide a
implementation of exception-style error handling in Bash, with `try-catch`
blocks, error "types", and stack traces.

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
CommandError/cat/1: command 'cat /bad/path/' returned non-zero exit status 1
```

([More examples below][examples].)

Exceptions are just strings, and their "types" are just prefixes like 
"TypeError". The exception throwing/catching state is stored in a global 
variable, and is propagated using Bash's normal error handling, until it's
handled like a normal error or by a matching `try-catch-ryt` block. We use
Bash traps to reset the exception state if an error is handled outside of a
`catch` block, and to display the stack trace if one isn't handled at all.

Implementation in [`exceptions.bash`][2]
----------------------------------------

```bash

# Environment
{ 
  # Enable typical Bash error handling.
  set -euo pipefail

  # Ensure a known-compatible version of Bash.
  (( "${BASH_VERSINFO[0]}" >= 4 )) && readonly BASH_COMPAT=4.2

  # Propagate RETURN, ERR, and DEBUG traps to functions and subshells.
  set -o errtrace -o functrace

  # Enable Bash aliases (disabled in scripts by default, but we require them).
  shopt -s expand_aliases
}

# Utility functions
{ 
  # Returns the specified exit status, implicitly setting $?. Does nothing else.
  # 
  # Used to set the exit status of a block explicitly without returning or
  # exiting from the enclosing function or subshell.
  function ?= {
    return "${1?}"
  }

  # Enable __red__ coloring if stdin is a terminal unless NO_COLOR is set.
  if tty > /dev/null && [[ ! ${NO_COLOR+set} ]]; then
    function __red__ {
      printf "%s%s%s" "$(tput setaf 1 || :)" "$*" "$(tput sgr0 || :)"
    }
  else 
    function __red__ {
      printf "%s" "$*"
    }
  fi
}

# Internal exception state and functions
{ 
  # We "throw" an exception by setting these global variables.
  declare -g __THROWN_MESSAGE__=""
  declare -g __THROWN_STACK__=""

  # We "catch" by unsetting those and moving the values here instead.
  declare -g __CAUGHT_MESSAGE__=""
  declare -g __CAUGHT_STACK__=""

  function __capture__exception__ {
    echo ""

    # arbitrary value, but ideally   
    return 69
  }

  function __on_err__ {
    return "$?"
  }

  function __on_return__ {
    return "$?"
  }

  function __on_exit__ {
    return "$?"
  }

  trap __on_err__ ERR
  trap __on_return__ RETURN
  trap __on_exit__ EXIT
}

# Exception syntax
{
  alias throw='{ __THROWN_MESSAGE__="$(cat -) [at $(caller 0)]"; return 69; } <<<'

}

# Our try-catch-yrt syntax wraps a block with a check for that status code
# being returned with __THROWN_MESSAGE__ set. If so, the __catch_or_rethrow__ function
# is used to compare the __THROWN_MESSAGE__ value to the caught prefix. If there's a
# match, the catch block is run the error is suppressed. If it doesn't match,
# the exception is re-thrown. If the try block exits with a non-zero exit
# status, but no exception it is normalized to an exit status of 1 (TODO:
# preserve instead?) and propagated.
alias try='if { '
alias catch=' } || [[ $? = 69 && $__THROWN_MESSAGE__ ]]; then { __catch_or_rethrow__ '
alias yrt='}; else return 1; fi'
function __catch_or_rethrow__ {
  local exception_prefix="${1:-}"
  if ! [[ $__THROWN_MESSAGE__ ]]; then
    echo "$(__red__ FatalError: __catch_or_rethrow__ called but nothing thrown)" >&2
    exit 1
  elif [[ $__THROWN_MESSAGE__ == $exception_prefix* ]]; then
    __CAUGHT_MESSAGE__="$__THROWN_MESSAGE__"
    __THROWN_MESSAGE__=
    return 0
  else
    # re-throw
    return 69
  fi
}
# Use the $(caught) function to reference to the exception in a catch block.
function caught {
  if [[ $__CAUGHT_MESSAGE__ ]]; then
    printf "%s" "$__CAUGHT_MESSAGE__"
  else
    printf "RuntimeError: caught called outside of catch block"
  fi
}

:<<'```bash' pardon the mess
```

Examples in [`exceptions.bash`][2]
----------------------------------

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
    throw "ArgumentError: expected 1 argument, got: ${#@}"
  fi
  if ! [[ $1 =~ ^[0-9]+$ ]]; then
    throw "TypeError: expected integer for argument 1, got: $1"
  fi
  if (( $1 < 0 )); then
    throw "RangeError: argument 1 was too small, expected >= 0, got: $1"
  fi
  if (( $1 > 100 )); then
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

:<<'<!-- -->' pardon the mess
```

Caveats
-------

This is a gross hack. Don't hold me responsible if you use it in prod code.

This implementation doesn't account for sub-shells (which are created almost 
any time you use parantheses in Bash). The errors will still be propagated but
the exception message and stack trace will be lost.

Try blocks only catch errors thrown from functions calls. If there's a `throw`
directly inside the `try` block, it won't be caught.

Each `try` block can only have one `catch` block, it can't have different ones
for each type.

Syntax error messages are gibberish.

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

Appendix 1: Bash manual description of `-e`/`-o errexit` setting
----------------------------------------------------------------

When I refer to regular Bash error handling above, I am referring to the
various ways a command's failure (nonzero exit status) can be suppressed,
instead of exiting the script, while the `-e`/`-o errexit` setting is enabled.
These are described below in the Bash manual's description of the setting.   

> Exit immediately if a pipeline (which may consist of a single simple command),
> a list, or a compound command (see SHELL GRAMMAR above), exits with a non-zero
> status. The shell does not exit if the command that fails is part of the
> command list immediately following a `while` or `until` keyword, part of the
> test following the `if` or `elif` reserved words, part of any command executed
> in a `&&` or `||` list except the command following the final `&&` or `||`,
> any command in a pipeline but the last, or if the command's return value is
> being inverted with `!`. If a compound command other than a subshell returns a
> non-zero status because a command failed while `-e` was being ignored, the
> shell does not exit. A trap on `ERR`, if set, is executed before the shell
> exits. This option applies to the shell environment and each subshell
> environment separately (see COMMAND EXECUTION ENVIRONMENT above), and may
> cause subshells to exit before executing all the commands in the subshell.
>
> If a compound command or shell function executes in a context where `-e` is
> being ignored, none of the commands  executed  within the compound command or
> function body will be affected by the `-e` setting, even if `-e` is set and a
> command returns a failure status. If a compound command or shell function sets
> `-e` while executing in a context where `-e` is ignored, that setting will not
> have any effect until the compound command or the command containing the 
> function call completes.

<!-- link targets -->

  [1]: ./exceptions.txt
  [2]: ./exceptions.bash
  [A1]: #appendix-1-bash-manual-description-of--e-o-errexit-setting
  [examples]: #examples-in-exceptionsbash
  [hire me!]: #are-you-hiring-im-looking

<!-- -->
