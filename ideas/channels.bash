#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit compat"${BASH_COMPAT=42}"

# The maximum size in bytes for which a write to a pipe is guaraunteed to be 
# atomic by the operating system. (Reads are ~never guaraunteed to be atomic.)
# but this is mostly useless because Bash string lengths depend on the damn locale!
declare -i PIPE_BUF
PIPE_BUF="$(getconf PIPE_BUF /)"

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

  declare tmp_path
  tmp_path="$(mktemp -u)"
  mkfifo "$tmp_path"
  declare fd
  exec {fd}<>"$tmp_path"
  rm "$tmp_path"

  declare -gri "${name}=${fd}"

  # "Unsafe" here refers to a lack of concurrency guarauntees -- if multiple
  # processes are both reading or both writing at the same time, the results
  # are undefined. Messages may be corrupted or lost. 
  eval "function ${name}.send-unsafe {
    channel-send \$${name} \"\$@\"
  }"
  eval "function ${name}.recv-unsafe {
    channel-recv \$${name} \"\$@\"
  }"
  # We can use filesystem locking to prevent that. This can reduce performance
  # by 80% (from 2ms to 10ms), which is horribly slow compared with other 
  # programming languages, but more than adequate for my Bash needs.
  eval "function ${name}.send {
    flock --exclusive --timeout \$channel_timeout \$$name
    ${name}.send-unsafe \"\$@\"
    flock --unlock \$$name
  }"
  eval "function ${name}.recv {
    flock --exclusive --timeout \$channel_timeout \$$name
    ${name}.recv-unsafe \"\$@\"
    flock --unlock \$$name
  }"
}

# Sends a message into a channel, by writing it to the specified file descriptor
# followed by the channel message delimiter.
function channel-send {
  declare -i channel_fd="$1"
  echo >&"$channel_fd" "${@:2}"
  echo >&"$channel_fd" "$channel_delimiter"
}

# Reads the next message from a channel, raising an error if none is available.
function channel-recv {
  declare -i channel_fd="$1"
  declare line
  while true; do
    if ! read -u "$channel_fd" -r -t "$channel_timeout" line; then
      echo >&2 "ERROR: read from &$channel_fd failed after ${channel_timeout}s"
      return 1
    elif [[ $line = "$channel_delimiter" ]]; then
      return 0
    else
      echo "$line"
    fi
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
