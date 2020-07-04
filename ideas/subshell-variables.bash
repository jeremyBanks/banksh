#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit compat"${BASH_COMPAT=32}"

# Creates and opens a fifo (named pipe), then unlinks it from the filesystem (so
# that only our process has access to it), then prints its file descriptor.
# We use this parent for child processes to communicate with their parents.
declare to_parent
declare to_parent_tmp_path
to_parent_tmp_path="$(mktemp -u)"
mkfifo "$to_parent_tmp_path"
exec {to_parent}<>"$to_parent_tmp_path"
rm "$to_parent_tmp_path"

function return-eval {
  echo >&"$to_parent" "$@"
  echo >&"$to_parent" EOF
  exit
}

set -x

flock --exclusive "$to_parent"
: "$(
  # objective 1: set state outside of this subshell from inside it.
  return-eval '
    declare global_var=2
    echo "Im global! $global_var"
  '
)"
declare line_from_child
declare lines_from_child=""
while true; do
  read -u "$to_parent" -r -t1 line_from_child;
  if [[ $line_from_child = EOF ]]; then
    break
  fi
  lines_from_child+="$line_from_child"$'\n'
done
flock --unlock "$to_parent"
eval "$lines_from_child"



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
