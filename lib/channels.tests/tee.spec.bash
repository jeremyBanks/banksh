# shellcheck source=../channels
source "$(dirname "${BASH_SOURCE[0]}")/../../.banksh/lib/channels"


: '
declare-channel C defines:
variable C          -- the file descriptor id for the channel
function C.recv     -- thread-safe blocking read
function C.try-recv -- thread-safe non-blocking read or fail
function C.send     -- thread-safe blocking write
  *-unsafe thread-unsafe variants of the above, without the locking (5x faster) 
function C.drop     -- closes the file descriptor and deletes its variables/functions
'

declare -i input output_a output_b
declare-channel input
declare-channel output_a
declare-channel output_b

# Tee messages from an input channel to two output channels.
(
  while true; do
    declare message
    message="$(input.recv)"
    output_a.send "$message"
    output_b.send "$message"
  done
) &

declare tee_pid="$!"

input.send 1
input.send 2
input.send 3

[[ $(output_a.try-recv) = 1 ]]
[[ $(output_b.try-recv) = 1 ]]

input.send 4

[[ $(output_a.try-recv) = 2 ]]
[[ $(output_b.try-recv) = 2 ]]
[[ $(output_a.try-recv) = 3 ]]
[[ $(output_b.try-recv) = 3 ]]
[[ $(output_a.try-recv) = 4 ]]
[[ $(output_b.try-recv) = 4 ]]

kill "$tee_pid"
wait

input.send 5

(! output_a.try-recv 2>/dev/null)
(! output_b.try-recv 2>/dev/null)

echo "done"
