#!/bin/bash
:<<'```bash' [pardon the mess, this is an imperfect Bash-Markdown polyglot.][1]

Exception-Style Error Handling in Bash
======================================

posted by [Jeremy Banks] in July 2020  
you may [discuss this on dev.to],
reuse it under MIT or CC-BY-NC-2.0,
or [hire me]

With the typical `-euo pipefail` error options enabled, unhandled errors in
Bash scripts are propagated up the call stack until they're handled or exit the
script (see [details below][A1] if you're unfamiliar). However, the only
associated data is the exit status code: less than a byte of information. This
works, but if you want to handle different types of errors separately, you may
find yourself writing a lot of boilerplate.

With a relatively modern version of Bash and some creativity, we can do better.
I present a proof-of-concept using aliases, traps, and functions to provide a
implementation of exception-style error handling in Bash, with `try-catch`
blocks, error "types", and stack traces.

```sh
source exceptions.bash

function fread {
  if [[ ! -f $1 ]]; then
    throw IOError: "the file '$1' does not exist"
  else
    cat "$1"
  fi
}

try # XXX: is this broken because of subshells? man you need to test this.
  declare contents="$(fread "$1")"
catch IOError
  echo "Are you sure entered that path correctly? $(caught)"
  exit 1
yrt

echo "The file named '$1' contained ${#contents} characters."
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
source exceptions.bash

function event-loop {
  while true; do
    tick
    sleep 1
  done
}

function tick {
  cat /bad/path
}

event-loop
```

```
$ bash example-2
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

# Private utility functions
{
  # Returns the specified exit status, implicitly setting $?. Does nothing else.
  #
  # May be used to set the exit status of a block explicitly without returning
  # or exiting from the enclosing function or subshell.
  function __status__ {
    return "${1?}"
  }

  # We only enable styles if stdio is all-terminal and NO_COLOR is not set.
  if [[ -t 0 && -t 1 && -t 2 ]] && [[ ! ${NO_COLOR+set} ]]; then
    # Applies a dash-delimited list of text styles, specified by the first
    # argument, to the remaining arguments, printing the formatted text.
    function __style__ {
      printf "%s" "$__style_reset__"
      declare names
      names=${1//-/ }
      for name in $names; do
        declare -n color="__style_${name}__"
        if [[ ! ${color+set} ]]; then
          throw ValueError: "invalid style name: $name"
        fi
        printf "%s" "$color"
      done
      printf "%s" "${*:2}"
      printf "%s\n" "$__style_reset__"
    }

    # Text styles we use, or empty strings if tput doesn't recognize $SHELL.
    declare -r __style_red__="$(tput setaf 9 || :)"
    declare -r __style_yellow__="$(tput setaf 3 || :)"
    declare -r __style_bold__="$(tput bold || :)"
    declare -r __style_underline__="$(tput smul || :)"
    declare -r __style_reset__="$(tput sgr0 || :)"
  else
    # If styles aren't enabled, skip the first argument, print the rest as-is.
    function __style__ {
      echo "${*:2}"
    }
  fi
}

# Private exception state and functions
{
  # We "throw" an exception by setting these global variables.
  declare -i __thrown_status__=0
  declare __thrown_message__=""
  declare __thrown_stack__=""

  # We "catch" by unsetting those and moving the values here instead.
  declare -i __caught_status__=0
  declare __caught_message__=""
  declare __caught_stack__=""

  # Original working directory, required to resolve relative source paths.
  declare -r __owd__="$(realpath "$(pwd)")"

  # If an error is unhandled, throw an anonymous exception
  trap '__on_err__ "$?" "$BASH_COMMAND"' ERR
  function __on_err__ {
    declare -r status="$1"
    declare -r command="$2"

    if (( __thrown_status__ = 0 )); then
      __status__ "$status" || throw CommandError: "Command '$command' failed with status $status"
    fi

    return "$status"
  }

  # If a function returns successfully, but an exception is still set, that
  # means an error was handle without using a catch block. That's not a
  # problem; we clear it here.
  trap '{
    __returned_status__="$?"
    if (( __returned_status__ = 0 )); then
      __thrown_status__=0
      __thrown_message__=""
      __thrown_stack__=""
    fi
  }' RETURN

  # If the script exits with an error, we display the unahndled exception and
  # stack trace, if known, else a simple error message.
  trap '__on_exit__ $?' EXIT
  function __on_exit__ {
    declare -r status="$1"

    if [[ $status != 0 ]]; then
      if [[ $__thrown_message__ ]]; then
        echo "$__thrown_stack__"$'\n'"$(__style__ bold "$__thrown_message__")" >&2
      else
        __style__ red "Failed with exit status $status." >&2
      fi
    fi

    return "$status"
  }
}

# Public exception syntax
{
  # The `throw` function allows you to raise an exception with a specific
  # type/message. It should be called in this style:
  #   throw SomeTypeOfError: "a string message"
  function throw {
    declare -i status="$?"

    declare message="$*"
    declare stack
    stack="$(__style__ red-underline "Traceback (most recent call last):")"

    if [[ ! $message ]]; then
      message="UnknownError"
      if [[ $status != 0 ]]; then
        message="UnexpectedStatus${status}Error"
      fi
    fi

    declare -i i
    for ((i = ${#FUNCNAME[@]} - 1; i >= 1; i -= 1)); do
      declare line="${BASH_LINENO[$((i - 1))]}"
      declare command="${FUNCNAME[$i]}"
      declare file="${BASH_SOURCE[$i]}"

      stack+=$'\n'"  File \"$file\", line $line"
      if (( i + 1 < ${#FUNCNAME[@]} )) || [[ $command != main ]]; then
        # Bash identifies the top-level as though it were a function named
        # "main". We want to remove that potential confusion.
        stack+=", in $(__style__ yellow "$command")"
      fi
      stack+="$(
        cd "$__owd__";
        declare line_content
        line_content="$(
          awk -v n="$line" "NR == n" "$file" | sed -e 's/^ *//' || :)";
        if [[ $line_content ]]; then
          echo
          echo "    $line_content"
        fi
      )";
    done

    if [[ $__caught_message__ ]]; then
      stack="$__caught_stack__
$(__style__ bold "$__caught_message__")

During handling of the above exception, another exception occurred:

$stack"
    fi

    if [[ $status == 0 ]]; then
      status=69
    fi

    __thrown_message__="$message"
    __thrown_stack__="$stack"
    __thrown_status__="$status"

    return "$status"
  }

  # Our try-catch-yrt syntax wraps a block with a check for that status code
  # being returned with __thrown_message__ set. If so, the __catch_or_raise__ function
  # is used to compare the __thrown_message__ value to the caught prefix. If there's a
  # match, the catch block is run the error is suppressed. If it doesn't match,
  # the exception is re-thrown. If the try block exits with a non-zero exit
  # status, but no exception it is normalized to an exit status of 1 (TODO:
  # preserve instead?) and propagated.
  alias try='{'
  alias catch='} || { __catch_or_raise__ '
  alias finally='FINALLY IS NOT IMPLEMENTED'
  alias yrt='}'
  function __catch_or_raise__ {
    declare exception_prefix="${1:-}"
    if (( __thrown_status__ == 0 )); then
      __style__ red FatalError: __catch_or_raise__ called but nothing thrown >&2
      exit 1
    elif [[ $__thrown_message__ == $exception_prefix* ]]; then
      __caught_status__="$__thrown_status__"
      __caught_message__="$__thrown_message__"
      __caught_stack__="$__thrown_stack__"
      __thrown_status__=0
      __thrown_message__=""
      __thrown_stack__=""
      return 0
    else
      # re-throw
      return 69
    fi
  }

  # Use the $(caught) function to get the exception message in a catch block.
  function caught {
    if [[ $__caught_message__ ]]; then
      echo "$__caught_message__"
    else
      echo "RuntimeError: caught called outside of catch block"
      return 1
    fi
  }
}

# If this file has been sourced for use as a library, we're done, return now.
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  return 0
fi

# Otherwise, it has been run directly, so we'll continue and run the examples.


:<<'source exceptions.bash' pardon the mess
```

Examples in [`exceptions.bash`][2]
----------------------------------

```bash
source exceptions.bash

function examples {
  try
    example-1
  catch ""
    throw UhOhError: "caught an exception ($(caught)), what do I do? oh no!"
  yrt
}

function example-1 {
  throw ExampleError: oh noes
}

# Run the examples.
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

Potential Future Work
---------------------

### Extensible exception metadata

Instead of just storing exception data as a string, we could store it as a Bash
assocative array (string map/dictionary), and allow arbitrary key-value pairs to
be attached. This could be provided as a `throw(( ... ))` variant of the
`throw [...]` statement.

```bash
throw((
  [message]=TypeError: "expected integer, but got a string (\"\")"
  [exit-status]=3
  [example-foo-api-error-code]=FOO-1234
))
```

We would extend the `caught` function to accept an optional second argument,
such as `$(caught exit-status)`, or `$(caught stack-trace)`, maintaing the
default `$(caught)` as equivalent to `$(caught message)`.

### Implement this as a patch for Bash itself

I've never looked at Bash's source code, but this feature isn't too complicated,
so it should be a feasible and educational exercise to implement as part of Bash
itself.

To Do (before publishing this post)
-----------------------------------

- catch different exception types
- finally block
- test what happens with sub-shells.
- instructions for "if you'd like to just use it, do this, else here's the impl"
- can we support immediately-thown exceptions? maybe we already do now? test it.
- update initial examples, consider screenshots.
- preserve exit status of captured stuff
- test behaviour with -c command line or stdin scripts -- do we break?

Are you hiring? I'm looking!
----------------------------

I'm looking for a new full-time permanent position as a software developer.

I have 8 years experience, including at Google and Stack Overflow. I've mostly
done full-stack web development (including TypeScript, Python, React, Django,
and some C# ASP.NET), with a recent focus in developer tools. I'd be happy to
do more of that, but would also be excited by an opportunity to work
professionally with Rust, which I've used for some side projects but nothing
serious. I'm more interested in finding a good fit than a top salary.

I'm located in Toronto, Canada but would prefer a remote or mostly-remote
position.

Check out my profile on LinkedIn at <https://linkedin.com/in/jeremy-banks/>
or email me at <mailto:_@jeremy.ca> or <mailto:jeb@hey.com>.

Acknowledgments
---------------

Thanks to [Jacob Haven] for providing feedback on drafts of this post.

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
  [hire me]: #are-you-hiring-im-looking
  [discuss this on dev.to]: https://dev.to/banks/typed-exceptions-with-stack-traces-in-bash-226n
  [Jeremy Banks]: mailto:_@jeremy.ca
  [Jacob Haven]: https://github.com/jacobhaven

<!-- -->
