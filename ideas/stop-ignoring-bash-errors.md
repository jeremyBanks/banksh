Stop Ignoring Bash Errors
=========================

posted by [Jeremy Banks], July 2020  
you may [discuss this on dev.to]

  [Jeremy Banks]: mailto:_@jeremy.ca
  [discuss this on dev.to]: https://dev.to/banks/stop-ignoring-bash-errors-1omi
  [tags]: / "bash linux tutorial"
  [canonical]: https://banksh.jeremy.ca/ideas/stop-ignoring-bash-errors

There are few things more frustrating than starting a program, only for it to silently crash, without any error message to tell you what went wrong. One of those few things is for the program to accidentally ignore an error, telling you that everything's fine, but continuing in an invalid state and silently corrupting your data.

Bash makes it easy to accidentally write scripts that do both. 😬

However, with a bit of care it is possible to write robust, reliable scripts that keep you and your users happy. Here are some error handling practices to keep in mind.

## What do we mean by errors?

Bash doesn't have exceptions or error types as we might be used to in other langues. However, every command, whether it's built-in to Bash or an external program, returns an "exit status code" between `0` and `255` when it finishes executing. Successful commands return `0`, while commands that fail return a between code between `1` and `255`.

When I talk about "errors" in Bash in this post, I'm referring to any command which exits with a non-zero exit code in a context where it isn't explicitly expected. For example, if you had a program that started with

```bash
cat example.txt
```

and `example.txt` did not exist, that would be an error. Nothing is handling the failure, so the program would either crash or continue in an invalid state. However if you have an `if` statement like

```bash
if test -e example.txt; then
  echo "Example found"
else
  echo "Example not found"
fi
```

the command `test -e example.txt` may fail, but the `if` statement is expecting its condition to be a command that might fail, and it handle that case automatically. I do *not* consider that an "error" for the purpose of this post. The same reasoning applies to cases like `while COMMAND; do ...` and `COMMAND || return 0`; see [the Bash manual][A1] for the full list of exceptions.

## Simple errors

By default, Bash scripts will ignore most errors and continue running. The first thing we need to do in our scripts is enable Bash's basic error handling options, as follows. (This is a very common practice.)

```bash
set -euo pipefail
```

Here we enabling three options at once. Let's break them down.

`set -e` (aka `-o errexit`) causes *most* failing commands to immediately return from the enclosing function, propagating their error exit status code to the calling function. If the calling function also doesn't handle the error, it will continue up the stack, eventually exiting the script with that exit status code. Unfortunately, even with this option enabled there are several cases where errors can be silently ignored, as we'll discuss below under *Subshells*.

`set -u` (aka `-o nounset`) makes it an error to refer to a variable like `$X` if it hasn't been defined, either in the script or as an environment variable, instead of treating it as an empty string. Often, this is a typo and a bug. There are certainly some cases where you'll need to handle reference possibly-undefined variables, but they should be indicated explicitly: you can use `${X-}` instead of `$X` to indicate where you'd like to use an empty string if a variable isn't defined.

`set -o pipefail` prevents errors from being silently ignored in pipelines (when the output of one command is being piped to the input of another). For example, consider:

```bash
cat example.txt | grep metadata | sort
```

By default, the exit status of the entire pipeline will just be that of the last command, `sort`. This can succeed even if `example.txt` does not exist and an earlier command like `cat` fails. `pipefail` changes this behaviour so that the pipeline is marked as failed if *any* of the commands fail. (Subsequent commands in the pipeline will still be executed. If multiple fail, the exit status of the last failing command will be used.)

wait is `inherit_errexit` the option I needed?!

SHOULD THIS ENTIRE POST BE ABOUT THAT?!

## ShellCheck

Adopting those settings made my scripts much more reliable, but I was still finding some bugs in them. They came from me misunderstanding subtleties of Bash's syntax, where my code wasn't doing what I thought it was doing. I might forget which terms need quoting in a condition like `[[ $x -eq "$y" ]]`, or where I can and can't omit the `$` before a variable in an expression like `$(( x = y ))`. I tried to keep the rules straight, but there were too many to absorb at once and it felt hopeless, until I discovered ShellCheck.

[ShellCheck](https://github.com/koalaman/shellcheck) is a static analysis tool/linter for Bash scripts, and it is *invaluable*. I use it in VS Code ([extension](https://marketplace.visualstudio.com/items?itemName=timonwong.shellcheck)) and run it in CI. It flags [cases where your code might not be doing what you expect](https://github.com/koalaman/shellcheck/blob/master/README.md#user-content-gallery-of-bad-code), with links to [wiki pages explaining the problem and potential alternatives](https://github.com/koalaman/shellcheck/wiki/SC2035).

Most of my recent Bash learnings have started with a ShellCheck warning code making me aware of an edge case or capability that I hadn't considered. Like any linter, you may occasionally need to ignore its warnings with an annotation like `# shellcheck disable=SC2034`, but I've found its advice is usually very good, even when it seemed counterintuitive at first.

Even with ShellCheck, there are still some subtle cases where you can silence errors without realizing it, but not many.

## Subshells

A lot of things about Bash have surprised me, but this was the most shocking: almost anywhere you use parentheses, Bash *forks the entire process* to create a "subshell" child process running the parenthesized code!

```bash
(false || true || echo this is a subshell) && ls

echo "$(ls also-this)" "$(ls this-too)"

my_function() (
  echo this is a subshell
)

other_function() {
  echo but this is NOT, because I used braces instead of parentheses
}

```

One of the things I was most shocked to learn about Bash was that almost every time

it suprise dme64

how do they behave? fine.

### The unfortunate case of command substitution

Shut it can bevverd

Further reading. 

Defensive bash

Shell check

Not even catch 

WHAT DO I WANT TO COMMUNICATE
cases where errors are suppressed that you might not expect.
not cases where it's obvious and expected.

## Further questions

Do you know how to deal?

## Appendix 1: Bash manual description of the `-e`/`-o errexit` setting

  [A1]: #appendix-1-bash-manual-description-of-raw-e-endraw-raw-o-errexit-endraw-setting

> Exit immediately if a pipeline (which may consist of a single simple command), a list, or a compound command (see SHELL GRAMMAR above), exits with a non-zero status. The shell does not exit if the command that fails is part of the command list immediately following a `while` or `until` keyword, part of the test following the `if` or `elif` reserved words, part of any command executed in a `&&` or `||` list except the command following the final `&&` or `||`, any command in a pipeline but the last, or if the command's return value is being inverted with `!`. If a compound command other than a subshell returns a non-zero status because a command failed while `-e` was being ignored, the shell does not exit. A trap on `ERR`, if set, is executed before the shell exits. This option applies to the shell environment and each subshell environment separately (see COMMAND EXECUTION ENVIRONMENT above), and may cause subshells to exit before executing all the commands in the subshell.
>
> If a compound command or shell function executes in a context where `-e` is being ignored, none of the commands  executed  within the compound command or function body will be affected by the `-e` setting, even if `-e` is set and a command returns a failure status. If a compound command or shell function sets `-e` while executing in a context where `-e` is ignored, that setting will not have any effect until the compound command or the command containing the function call completes.
>
> *source:* `{ COLUMNS=2048 man bash | grep -Em1 -A32 '^\s+set \[' | grep -Em1 -A32 '^\s+-e\s{4}' | grep -Em2 -B32 '^\s+-.\s{4}' | sed '$d' | grep -EoA32 '\s{4}(\S\s{0,4})+$' | grep -Eo '\S.*$' | fmt -tw$COLUMNS; }`
