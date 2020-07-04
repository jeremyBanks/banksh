#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit compat"${BASH_COMPAT=32}"

# A unique random delimiter for channel messages.
readonly channel_delimiter="$$-$BASHPID-$SHLVL-$BASH_SUBSHELL-$SECONDS-$RANDOM"

# Creates and opens a fifo (named pipe), then unlinks it from the filesystem (so
# that only our process has access to it), then prints its file descriptor.
# We use this pipe for child processes to communicate with their parents.
declare -i channel_timeout=1
declare -i channel
declare channel_tmp_path
channel_tmp_path="$(mktemp -u)"
mkfifo "$channel_tmp_path"
exec {channel}<>"$channel_tmp_path"
rm "$channel_tmp_path"

function chan-send {
  echo >&"$channel" "$@"
  echo >&"$channel" "$channel_delimiter"
  exit
}

function chan-recv {
  declare line_from_child
  while true; do
    read -u "$channel" -r -t"$channel_timeout" line_from_child;
    if [[ $line_from_child = "$channel_delimiter" ]]; then
      break
    fi
    echo "$line_from_child"
  done
}

set -x

: "$(
  # objective 1: set state outside of this subshell from inside it.
  chan-send '
    declare global_var=2
    echo "Im global! $global_var"
  '
)"
eval "$(chan-recv)"



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
