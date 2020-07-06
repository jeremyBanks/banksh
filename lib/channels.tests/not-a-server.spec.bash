# shellcheck source=../channels
source "$(dirname "${BASH_SOURCE[0]}")/../../.banksh/lib/channels"

declare-channel request
declare-channel response

(
  function ipc-double-integer {
    declare -i n="$1"
    echo "$((n * 2))"
  }

  declare command result
  while true; do
    command="$(request.recv)"
    if [[ $command = exit ]]; then
      exit
    fi
    result="$(ipc-$command)"
    response.send "$result"
  done
) &

function ipc {
  request.send "$@"
  if [[ ${1} != exit ]]; then
    response.recv
  fi
}

ipc double-integer 16
ipc double-integer 0
ipc double-integer -4
ipc exit
