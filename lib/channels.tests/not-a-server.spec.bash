# shellcheck source=../channels
source "$(dirname "${BASH_SOURCE[0]}")/../../.banksh/lib/channels"

declare-channel lock
declare-channel request
declare-channel response

(
  function ipc-double-integer {
    declare -i n="$1"
    echo "$((n * 2))"
  }

  function ipc-increment-integer {
    declare -i n="$1"
    echo "$((n + 1))"
  }

  declare command result
  while true; do
    command="$(request.recv)"
    echo "got command >$command<"
    if [[ $command = exit ]]; then
      exit
    fi
    result="$(ipc-$command)"
    response.send "$result"
  done
) &

function ipc {
  flock --exclusive $lock
  request.send "$@"
  if [[ ${1} != exit ]]; then
    response.recv
  fi
  flock --unlock $lock
}

declare pids=""

(
  sleep 1
  [[ $(ipc double-integer 16) = 32 ]]
  [[ $(ipc double-integer 32) = 64 ]]
  [[ $(ipc double-integer 3) = 6 ]]
  [[ $(ipc double-integer 1) = 2 ]]
  [[ $(ipc increment-integer 9) = 10 ]]
) &
pids+=" $!"

(
  sleep 1
  [[ $(ipc double-integer 1) = 2 ]]
  [[ $(ipc double-integer 16) = 32 ]]
  [[ $(ipc double-integer 3) = 6 ]]
  [[ $(ipc double-integer 32) = 64 ]]
  [[ $(ipc increment-integer 9) = 10 ]]
) &
pids+=" $!"

(
  sleep 1
  [[ $(ipc double-integer 3) = 6 ]]
  [[ $(ipc double-integer 32) = 64 ]]
  [[ $(ipc increment-integer 9) = 10 ]]
  [[ $(ipc double-integer 1) = 2 ]]
  [[ $(ipc double-integer 16) = 32 ]]
) &
pids+=" $!"

wait $pids

echo "subshells done"

ipc exit

echo "parent done"


# does the flock apply to the entire descriptor, not the process?
# hmmmm... does locking a file descriptor... lock the file descriptor universally, which might be shared across processes, not locking it to a specific process? maybe.... if so that's pretty, uh, inconvenient.
