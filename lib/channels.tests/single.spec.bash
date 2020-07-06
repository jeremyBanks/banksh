#!/bin/bash
# shellcheck source=./../../.banksh/lib/channels
source "$(dirname "${BASH_SOURCE[0]}")/../../.banksh/lib/channels"

declare -i sanity_check && declare-channel sanity_check
declare message

(
  sanity_check.send "hello world 1"
  sanity_check.send "hello world 2"
  # droping in a subshell won't affect the parent shell
  sanity_check.drop
)
(sanity_check.send "hello world 3")
message="$(sanity_check.recv)"
test "$message" = "hello world 1"
(
  message="$(sanity_check.recv)"
  test "$message" = "hello world 2"
)
message="$(sanity_check.recv)"
test "$message" = "hello world 3"
(! sanity_check.try-recv 2>/dev/null)
(! sanity_check.try-recv 2>/dev/null)
(sanity_check.send "hello world 4")
message="$(sanity_check.recv)"
test "$message" = "hello world 4"
(! sanity_check.try-recv 2>/dev/null)

: "$sanity_check"

# droping in the parent shell will affect subsequent subshells
sanity_check.drop

(! (: "$sanity_check" ))
(! sanity_check.send)
(! sanity_check.try-recv 2>/dev/null)
(! sanity_check.drop)
