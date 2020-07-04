#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit compat"${BASH_COMPAT=32}"

# first do it without nesting

set -x

# The maximum size for which a write to a pipe is guaraunteed to be atomic.
# (Reads are not guaraunteed to be atomic.)
declare PIPE_BUF
PIPE_BUF="$(getconf PIPE_BUF /)"

# Creates and opens a fifo (named pipe), then unlinks it from the filesystem (so
# that only our process has access to it), then prints its file descriptor.
function mkfifo-fd {
  declare fifo_tmp_path fifo
  fifo_tmp_path="$(mktemp -u)"
  mkfifo "$fifo_tmp_path"
  exec {fifo}<>"$fifo_tmp_path"
  rm "$fifo_tmp_path"
  echo "$fifo"
}

# A pipe we'll use for child processes to communicate with their parent.
declare child_to_parent
to_parent="$(mkfifo-fd)"

flock --exclusive "$to_parent"
(
  echo >&"$to_parent" echo hello
)
declare line_from_child
declare lines_from_child=""
while IFS= read -u "$to_parent" -r --timeout 0 "$line_from_child"; do
  lines_from_child+="$line_from_child"
done
flock --unlock "$to_parent"
eval "$lines_from_child"



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
