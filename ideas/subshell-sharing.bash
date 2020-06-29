set -euo pipefail

set -x

(( "${BASH_VERSINFO[0]}" >= 4 )) && readonly BASH_COMPAT=4.2

declare fifo_tmp_path="$(mktemp -u)"
mkfifo "$fifo_tmp_path"
exec {fifo}<>"$fifo_tmp_path"
rm "$fifo_tmp_path"

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
