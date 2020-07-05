eval "$(cat "$(dirname "${BASH_SOURCE[0]}")/../../.banksh/lib/channels")"

declare-channel sanity_check
declare message

(
  sanity_check.send "hello world 1"
  sanity_check.send "hello world 2"
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
(! sanity_check.recv) 2>/dev/null
(! sanity_check.recv) 2>/dev/null
(sanity_check.send "hello world 4")
message="$(sanity_check.recv)"
test "$message" = "hello world 4"
(! sanity_check.recv) 2>/dev/null

sanity_check.drop
