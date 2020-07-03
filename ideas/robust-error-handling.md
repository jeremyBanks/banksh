Robust error handling in Bash
=============================

posted by [Jeremy Banks] on the 2<sup>nd</sup> of July 2020  
you may [discuss this on dev.to][dev.to]

  [Jeremy Banks]: mailto:_@jeremy.ca
  [dev.to]: https://dev.to/banks/stop-ignoring-errors-in-bash-3co5
  [canonical]: https://banksh.jeremy.ca/ideas/robust-error-handling
  [tags]: # (#bash #linux #tutorial)

  [ShellCheck]: https://github.com/koalaman/shellcheck
  [extension]: https://marketplace.visualstudio.com/items?itemName=timonwong.shellcheck
  [gallery]: https://github.com/koalaman/shellcheck/blob/master/README.md#user-content-gallery-of-bad-code
  [SC2035]: https://github.com/koalaman/shellcheck/wiki/SC2035

Errors happen. Even if we write a perfect program, it might be provided with invalid input, or unexpectedly disconnected from the network. The key to writing reliable software isn't to prevent all errors, but to ensure that all errors are handled in a predictable way.

Bash does not enforce precise error handling. In fact, by default it simply ignores most errors. However, with a bit of care it is possible to write robust, reliable scripts that keep you and your users happy. Here are some error handling practices to keep in mind.

## What do we mean by errors?

Bash doesn't have exceptions or error types as we might be used to in other languages. However, every command, whether it's built-in to Bash or an external program, returns an "exit status code" between `0` and `255` when it finishes executing. Successful commands return `0`, while commands that fail return a code between `1` and `255`.

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

the command `test -e example.txt` may fail, but the `if` statement is expecting its condition to be a command that might fail, and it handles that case automatically. I do *not* consider that an "error" for the purpose of this post. The same reasoning applies to cases like `while COMMAND; do ...` and `COMMAND || return 0`; see [the Bash manual][A1] for the full list of exceptions.

## Simple errors

By default, Bash scripts will ignore most errors and continue running. The first thing we need to do in our scripts is enable Bash's basic error handling options, as follows.

```bash
set -euo pipefail
```

Here we enabling three options at once. Let's break them down.

`set -e` (aka `-o errexit`) causes *most* failing commands to immediately return from the enclosing function, propagating their error exit status code to the calling function. If the calling function also doesn't handle the error, it will continue up the stack, eventually exiting the script with that exit status code. (Note that there are still some cases where errors can be silently ignored, discussed below.)

`set -u` (aka `-o nounset`) makes it an error to refer to a variable like `$X` if it hasn't been defined, either in the script or as an environment variable, instead of treating it as an empty string. Often, this is a typo and a bug. There are certainly some cases where you'll need to handle possibly-undefined variables, but they should be indicated explicitly: you can use `${X-}` instead of `$X` to indicate where you'd like to use an empty string if a variable isn't defined.

`set -o pipefail` prevents errors from being silently ignored in pipelines (when the output of one command is being piped to the input of another). For example, consider:

```bash
cat example.txt | grep metadata | sort
```

By default, the exit status of the entire pipeline will just be that of the last command, `sort`. This can succeed even if `example.txt` does not exist and an earlier command like `cat` fails. `pipefail` changes this behaviour so that the pipeline is marked as failed if *any* of the commands fail. (Subsequent commands in the pipeline will still be executed. If multiple fail, the exit status of the last failing command will be used.)
 
Setting `set -euo pipefail` is a very common practice for many shells, but for Bash in particular there's one more option you should also be setting:

```bash
shopt -s inherit_errexit
```

By default, when you use command substitution in Bash, the `-e` setting is not applied. For example, if we had

```bash
echo "Command output: $(false; date)"
```

the command would successfully output the result of `date`, even though the failing `false` command should have exited the script first. Enabling `inherit_errexit` allows the command substitution to inherit our `-e` setting, so `date` will not be run. (However, please note that the error status of the command substitution is still ignored. Even though the parenthesized expression returned a nonzero exit status, `echo` will still run successfully. This is discussed in more detail [below][substitution].)

## ShellCheck

Adopting those settings made my scripts much more reliable, but I was still finding some bugs in them. Many came from me misunderstanding subtleties of Bash's syntax, where my code wasn't doing what I thought it was doing. I might forget which terms need quoting in a condition like `[[ $x -eq "$y" ]]`, or where I can and can't omit the `$` before a variable in an expression like `$(( x = y ))`. I tried to keep the rules straight, but there were too many to absorb at once and it felt hopeless, until I discovered ShellCheck.

[ShellCheck] is a static analysis tool/linter for Bash scripts, and it is *invaluable*. I use it in VS Code ([extension]) and run it in CI. It flags [cases where your code might not be doing what you expect][gallery], with links to [wiki pages explaining the problem and potential alternatives][SC2035].

Most of my recent Bash learnings have started with a ShellCheck warning code making me aware of an edge case or capability that I hadn't considered. Like any linter, you may occasionally need to ignore its warnings with an annotation like `# shellcheck disable=SC2034`, but I've found its advice is usually very good, even when it seemed counterintuitive at first.

Even with ShellCheck, there are still some subtle cases where you can silence errors without realizing it, but not many.

## Subshells

A lot of things about Bash have surprised me, but this was the most shocking: when you use parentheses to group commands, Bash *forks the entire process* to create a "subshell" child process running the parenthesized code!

```bash
(false || true || echo this is a subshell) && ls

echo "$(ls also-this)" "$(ls this-too)"

my_function() (
  echo this is a subshell
)

other_function() {
  echo but this is NOT, because I used curly braces instead of round parentheses
}
```

This is why if you try to set a global variable from inside of parentheses, the change won't be visible outside: you're only setting the value in the child process.

```bash
declare x=first
(x=second)
echo "$x"  # echoes "first"
```

This usually doesn't cause a problem for error handling&mdash;our settings are propagated to the subshell, and the exit status of the subshell is propagated back. However, there is one major exception...

### The unfortunate case of command substitution

  [substitution]: #the-unfortunate-case-of-command-substitution

Even with every available setting enabled, failures in command substitution subshells are usually silenced/masked and do not cause a failure in the original shell process. For example:

```bash
set -euo pipefail
shopt -s inherit_errexit

echo "$(
  echo >&2 "error: everything is broken"
  exit 66
)"

echo "but this is still running"
```

```
error: everything is broken
but this is still running
```

As far as I can tell, there is no way to change this behaviour, *and* ShellCheck can't warn about it. **If there is some way I've missed, please let me know!** There are workarounds, but they're clunky.

The exit status of these subshells *is* returned to the parent shell, however, it's never checked before it is overwritten by the return status of the original command (`echo` in the case above). If we put the command substitution in an assignment expression on its own, instead of as an argument to another command, the exit status won't be overwritten. For example:

```bash
set -euo pipefail
shopt -s inherit_errexit

declare output
output="$(
  echo >&2 "error: everything is broken"
  exit 66
)"
echo "$output"
```

```
error: everything is broken
```

This will behave properly, with the failure in `output="$(...)"` exiting the script.

## Bonus suggestions

The default handling of glob expressions in Bash is confusing. Consider the command

```bash
ls ./builds/bin-*/
```

If `builds` contains one or more directories whose names start with `bin-`, you'll get an argument for each, expanding to something like this:

```bash
ls ./builds/bin-windows/ ./builds/bin-linux/
```

However, if there's no match, the glob expression isn't replaced, it's just passed to the command as-is, typically producing an error or unexpected behaviour:

```
ls: cannot access './builds/bin-*/': No such file or directory
```

There are two more-reasonable alternative behaviours, and I strongly suggest you set one of them: `shopt -s nullglob` will replace the glob expression with the empty string if it doesn't match, and `shopt -s failglob` will raise an error.

Finally, you should set `shopt -s compat"${BASH_COMPAT=42}"` with the minimum Bash version you want to support, to reduce the chance of breakage in later versions. For Linux I usually target `42` (February 2011) but macOS only ships with `32` (October 2006).

## Conclusion

Writing robust Bash scripts is tricky, but not impossible. Start your scripts with `set -euo pipefail; shopt -s inherit_errexit nullglob compat"${BASH_COMPAT=42}` and use [ShellCheck], and you'll be 90% of the way there!

## Appendix 1: Bash manual description of the `-e`/`-o errexit` setting

  [A1]: #appendix-1-bash-manual-description-of-the-raw-e-endraw-raw-o-errexit-endraw-setting

> Exit immediately if a pipeline (which may consist of a single simple command), a list, or a compound command (see SHELL GRAMMAR above), exits with a non-zero status. The shell does not exit if the command that fails is part of the command list immediately following a `while` or `until` keyword, part of the test following the `if` or `elif` reserved words, part of any command executed in a `&&` or `||` list except the command following the final `&&` or `||`, any command in a pipeline but the last, or if the command's return value is being inverted with `!`. If a compound command other than a subshell returns a non-zero status because a command failed while `-e` was being ignored, the shell does not exit. A trap on `ERR`, if set, is executed before the shell exits. This option applies to the shell environment and each subshell environment separately (see COMMAND EXECUTION ENVIRONMENT above), and may cause subshells to exit before executing all the commands in the subshell.
>
> If a compound command or shell function executes in a context where `-e` is being ignored, none of the commands  executed  within the compound command or function body will be affected by the `-e` setting, even if `-e` is set and a command returns a failure status. If a compound command or shell function sets `-e` while executing in a context where `-e` is ignored, that setting will not have any effect until the compound command or the command containing the function call completes.
>
> *source:* `{ COLUMNS=2048 man bash | grep -Em1 -A32 '^\s+set \[' | grep -Em1 -A32 '^\s+-e\s{4}' | grep -Em2 -B32 '^\s+-.\s{4}' | sed '$d' | grep -EoA32 '\s{4}(\S\s{0,4})+$' | grep -Eo '\S.*$' | fmt -tw$COLUMNS; }`
