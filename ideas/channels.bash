#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit compat"${BASH_COMPAT=42}"

# The timeout (in seconds) after which we raise an error when attempting to
# send, recieve, or lock a channel. Must be at least 1ms or undefined behaviour.
declare channel_timeout=0.100

# A unique random delimiter for channel messages.
declare channel_delimiter="$$-$BASHPID-$SHLVL-$BASH_SUBSHELL-$RANDOM"

# Creates and opens a fifo (named pipe), then unlinks it from the filesystem (so
# that only our process has access to it), storing the file descriptor in the
# named global variable.
#
# Also defines four functions, $name.{send,recv}{,-unsafe}, imitating bound 
# methods wrapping our channel-{send,recv} functions defined below.
function declare-channel {
  declare name="$1"

  declare name_fd="${name}"
  declare name_send="${name}.send"
  declare name_recv="${name}.recv"

  declare tmp_path
  tmp_path="$(mktemp -u)"
  mkfifo "$tmp_path"
  declare fd
  exec {fd}<>"$tmp_path"
  rm "$tmp_path"

  declare -gri "${name_fd}=${fd}"

  # "Unsafe" here refers to a lack of concurrency guarauntees -- if multiple
  # processes are both reading or both writing at the same time, the results
  # are undefined. Messages may be corrupted or lost. 
  eval "function ${name_send}-unsafe {
    channel-send \$$name_fd \"\$@\"
  }"
  eval "function ${name_recv}-unsafe {
    channel-recv \$$name_fd \"\$@\"
  }"

  # We can use filesystem locking to prevent that. Don't deadlock yourself.
  eval "function ${name_send} {
    flock --exclusive --timeout \$channel_timeout \$$name_fd
    ${name_send}-unsafe \"\$@\"
    flock --unlock \$$name_fd
  }"
  eval "function ${name_recv} {
    flock --exclusive --timeout \$channel_timeout \$$name_fd
    ${name_recv}-unsafe \"\$@\"
    flock --unlock \$$name_fd
  }"
}

# Sends a message into a channel, by writing it to the specified file descriptor
# followed by the channel message delimiter.
function channel-send {
  declare -i channel_fd="$1"
  echo >&"$channel_fd" "${@:2}"
  echo >&"$channel_fd" "$channel_delimiter"
}

# Reads the next message from a channel, raises an error if none is available.
function channel-recv {
  declare -i channel_fd="$1"
  declare line
  while true; do
    if ! read -u "$channel_fd" -r -t "$channel_timeout" line; then
      echo >&2 "ERROR: read from &$channel_fd with timeout ${channel_timeout}s failed"
      exit 1
    fi
    if [[ $line = "$channel_delimiter" ]]; then
      break
    fi
    echo "$line"
  done
}

echo "Sanity testing..."

declare-channel sanity_check
(
  sanity_check.send "hello world"
)
declare message
message="$(sanity_check.recv)"
test "$message" = "hello world"

### Example Use: Setting global variables from a subshell
declare-channel to_parent

### also it is Benchmarking

echo "Benchmarking..."

declare -ri duration=16

declare message

declare -i unsafe_count=-1
SECONDS=0
while ((SECONDS < duration)); do
  : "$(to_parent.send-unsafe unsafe_count+=1)"
  message="$(to_parent.recv-unsafe)"
  eval "$message"
done

echo "$((unsafe_count / duration)) unsafe send+recvs per second ($unsafe_count / $SECONDS)"

declare -i safe_count=-1
SECONDS=0
while ((SECONDS < duration)); do
  : "$(to_parent.send safe_count+=1)"
  message="$(to_parent.recv)"
  eval "$message"
done

echo "$((safe_count / duration)) safe send+recvs per second ($safe_count / $SECONDS)"

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
