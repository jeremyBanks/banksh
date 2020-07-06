#!/bin/bash
# shellcheck source=./../../.banksh/lib/channels
source "$(dirname "${BASH_SOURCE[0]}")/../../.banksh/lib/channels"

declare -i channel && declare-channel channel

declare safe_message
safe_message="x$(printf "%-$((channel_max_message_length - 2))s" "")x"
declare -ri count=32

echo "sending $count messages of size $channel_max_message_length"
echo "recieving from the same process after every message"

declare -i i
for ((i = 0; i < count; i++)); do
  channel.send "$safe_message"
  channel.try-recv-unsafe > /dev/null
done

echo "done"
echo

echo "sending $count messages of size $channel_max_message_length"
echo "constantly recieving from a subshell"

(
  while true; do
    channel.recv-unsafe > /dev/null
  done
) &
declare ss_pid="$!"

for ((i = 0; i < count; i++)); do
  channel.send "$safe_message"
done

kill "$ss_pid"

echo "done"
