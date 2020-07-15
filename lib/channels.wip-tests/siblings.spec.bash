#!/bin/bash
# shellcheck source=./../../.banksh/lib/channels
source "$(dirname "${BASH_SOURCE[0]}")/../../.banksh/lib/channels"

echo "testing that two child shells can exchange messages with each other"
echo "in this case using the same channel, even though that's a bad idea"

declare -i channel && declare-channel channel

(
  channel.send "A"
  sleep 1
  [[ $(channel.recv) = B ]]
  [[ $(channel.recv) = C ]]
  [[ $(channel.recv) = D ]]
  channel.send "E"
  echo "subshell 1 done"
) &

(
  [[ $(channel.recv) = A ]]
  channel.send "B"
  channel.send "C"
  channel.send "D"
  echo "subshell 2 done"
) &

wait

[[ $(channel.recv) = E ]]
(! channel.try-recv) 2>/dev/null

echo "parent done"
