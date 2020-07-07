# shellcheck source=../channels
source "$(dirname "${BASH_SOURCE[0]}")/../../.banksh/lib/channels"

declare-channel input
declare-channel output_a
declare-channel output_b
declare-channel termination

# Tee messages from an input channel to two output channels.
(
  while ! termination.try-recv-unsafe 2>/dev/null; do
    declare message
    if message="$(input.try-recv)"; then
      output_a.send "$message"
      output_b.send "$message"
    fi
  done
  echo "subshell done"
) &

declare tee_pid="$!"

input.send 1
input.send 2
input.send 3

[[ $(output_a.recv) = 1 ]]
[[ $(output_b.recv) = 1 ]]

input.send 4

[[ $(output_a.recv) = 2 ]]
[[ $(output_b.recv) = 2 ]]
[[ $(output_a.recv) = 3 ]]
[[ $(output_b.recv) = 3 ]]
[[ $(output_a.recv) = 4 ]]
[[ $(output_b.recv) = 4 ]]

echo "parent done"

termination.send
