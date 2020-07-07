---
title: Go-inspired channels in Bash
tags: bash, linux
dev_community_url: https://dev.to/banks/bash-channels-subshell-communication-4p6h-temp-slug-5552669?preview=3b2770d1bddcafeef41b23fc68799efa4962e2c2bd534781581d191ac7986c6142bd8af51032b756ba3521898361fff441bab593e6fee565c6672591
posterity_url: https://banksh.jeremy.ca/ideas/robust-error-handling
---

Go-inspired channels in Bash
============================

posted by [Jeremy Banks] in the future  
you may [discuss this on dev.to][dev.to]

  [Jeremy Banks]: mailto:_@jeremy.ca
  [dev.to]: https://dev.to/banks/bash-channels-7d1-temp-slug-7698223?preview=22669ce95aeffdcc274331a05d2f895c29e3d32f9fda0c1f0879e9ca0ad680d1176385c3b45475a3c3191f12b9b756d8f52a5726b29c521d7fda8a31
  [canonical]: https://banksh.jeremy.ca/ideas/channels
  [tags]: # (#bash #linux #tutorial)

When you use parentheses to group commands, Bash forks (copies) the entire to create a "subshell" child process to run the parenthesized code. This has a lot of benefits, but it also has the drawback that if we change a global variable, that change only affects the variable in the subshell. The original process is unaffected.

```bash
#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit
BASH_COMPAT=3.1

declare x="first"
(
  echo "$x" # "first"
  x=second
  echo "$x" # "second"
)
echo "$x" # "first" again
```

I'd like to present a better way of doing this, yo. Light wrapper around
a fifo but it smooths off the edges.

If you're just using a subshell directly, like above, you could do this:

but with command substitution you can't do that, unless you also want to

If the buffer gets full it'll block.
In my experience on Linux it's like a megabyte.
