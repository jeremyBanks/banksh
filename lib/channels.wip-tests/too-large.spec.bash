#!/bin/bash
# shellcheck source=./../../.banksh/lib/channels
source "$(dirname "${BASH_SOURCE[0]}")/../../.banksh/lib/channels"

declare -i channel && declare-channel channel

declare unsafe_message
unsafe_message="x$(printf "%-$((channel_max_message_length + 1))s" "")x"

(! channel.send "$unsafe_message")
(! channel.try-recv 2>/dev/null)
