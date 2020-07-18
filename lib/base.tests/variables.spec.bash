#!/bin/bash
# shellcheck source=../../.banksh/lib/base
source /dev/null && eval "$(
  cat "$(dirname "$(realpath -- "$0")")/../../.banksh/lib/base" || echo exit 1)"

[[ $BASH_COMPAT = 4.2 ]]
[[ -d $__owd__ ]]
[[ -f $__file__ ]]
[[ $__dir__ ]]
[[ $__name__ ]]
[[ -f $__dir__/$__name__ ]]

echo "enabled options (set & shopt):"
(set -o && shopt) | grep -oP '^\S+(?=\s+on$)' | grep -vP '^checkwinsize$' | sort
