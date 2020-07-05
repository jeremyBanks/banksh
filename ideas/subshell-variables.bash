#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit compat"${BASH_COMPAT=42}"

### Channels in Bash

# A unique random delimiter for channel messages.
readonly channel_delimiter="$$-$BASHPID-$SHLVL-$BASH_SUBSHELL-$SECONDS-$RANDOM"

declare -i channel_timeout=1

# Creates and opens a fifo (named pipe), then unlinks it from the filesystem (so
# that only our process has access to it), storing the file descriptor in the
# named global variable.
function declare-channel {
  declare name="$1"

  declare name_fd="${name}"
  declare name_send="${name}.send"
  declare name_recv="${name}.recv"

  declare tmp_path
  declare fd
  tmp_path="$(mktemp -u)"
  mkfifo "$tmp_path"
  exec {fd}<>"$tmp_path"
  rm "$tmp_path"

  declare -gri "${name_fd}=${fd}"

  eval "function $name_send { channel-send \$$name_fd \"\$@\"; }"
  eval "function $name_recv { channel-recv \$$name_fd \"\$@\"; }"
}

### Example Use: Subshell Communication With Parent
declare-channel to_parent

function channel-send {
  declare -i channel_fd="$1"

  echo >&"$channel_fd" "${@:2}"
  echo >&"$channel_fd" "$channel_delimiter"
  exit
}

function channel-recv {
  declare -i channel_fd="$1"
  declare line
  while true; do
    read -u "$channel_fd" -r -t"$channel_timeout" line;
    if [[ $line = "$channel_delimiter" ]]; then
      break
    fi
    echo "$line"
  done
}

: "$(
  to_parent.send '
    declare global_var=2
    echo "Im global! $global_var"
  '
)"
eval "$(to_parent.recv)"



exit 0




# The maximum size for which a write to a pipe is guaraunteed to be atomic.
# (Reads are not guaraunteed to be atomic.)
declare PIPE_BUF
PIPE_BUF="$(getconf PIPE_BUF /)"


# Should we use a signal to trigger this immediately?
# SIGCONT seems appropriate.
# but interrupts are probably unneccessary

declare -a an_array=(1 2 3)
declare -A a_dict=([a]=1 [b]=2 [c]=3)

  : "[subshell $BASH_SUBSHELL]
    an_array = ${an_array[*]}
    a_dict keys = ${!a_dict[*]}
    a_dict values = ${a_dict[*]}
  "

(
  : "[subshell $BASH_SUBSHELL]
    an_array = ${an_array[*]}
    a_dict keys = ${!a_dict[*]}
    a_dict values = ${a_dict[*]}
  "

  an_array+=(4 5 6)
  a_dict+=([d]=4 [e]=5)

  : "[subshell $BASH_SUBSHELL]
    an_array = ${an_array[*]}
    a_dict keys = ${!a_dict[*]}
    a_dict values = ${a_dict[*]}
  "

  echo 'an_array=(IM IN UR ARRAY)' >&${fifo}
  echo '#' >&${fifo}
) &
eval "$(sed '/^#$/q' - <&${fifo})"

  : "[subshell $BASH_SUBSHELL]
    an_array = ${an_array[*]}
    a_dict keys = ${!a_dict[*]}
    a_dict values = ${a_dict[*]}
  "
