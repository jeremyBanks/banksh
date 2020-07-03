Setting global variables from Bash subshells
============================================

posted by [Jeremy Banks] in the future  
you may [discuss this on dev.to][dev.to]

  [Jeremy Banks]: mailto:_@jeremy.ca
  [dev.to]: https://dev.to/banks/subshell-variables-5heb-temp-slug-4697223?preview=c4bb0de6c75040c6e4cb8fe0c15365d0af75fbf2c17ad34a25c18d7a9bd8df3d3535fbf26c3abe57a5f857a4b713616603d07de34fe25cfeec889ffe
  [canonical]: https://banksh.jeremy.ca/ideas/subshell-variables
  [tags]: # (#bash #linux #tutorial)

When you use parentheses to group commands, Bash forks (copies) the entire to create a "subshell" child process to run the parenthesized code. This has a lot of benefits, but it also has the drawback that if we change a global variable, that change only affects the variable in the subshell. The original process is unaffected.

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit

declare x=first
(
  # in a subshell:
  echo "$x" # "first"
  x=second
  echo "$x" # "second"
)
echo "$x" # "first"
```
