: base.bash script framework
# shellcheck shell=bash

### Shell preconditions and settings.

if [[ "${BASH_VERSINFO[0]:-0}" -le 3 ]]; then
    echo "FATAL: bash>=4.2 required, but using: $("$(command -v "$(ps -cp "$$" -o command=)")" --version)";
    exit 1
elif [[ "$(basename "${BASH_SOURCE[0]}")" == "base.bash" ]]; then
    echo 'FATAL: base.bash is a script framework, not a script itself. It should be evaled:'
    # shellcheck disable=SC2016
    echo '    eval "$(cat "$(dirname "$0")/base.bash")"'
    exit 1
elif [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "FATAL: ${BASH_SOURCE[0]} is a script, not a library. Execute it, don't source it."
    exit 1
fi

# shellcheck disable=SC2034
readonly BASH_COMPAT=4.2

set -o monitor pipefail errexit errtrace functrace nounset noclobber
shopt -s nullglob globstar
shopt -u sourcepath

### Global constants.

readonly __owd__="$(realpath "$(pwd)")"
readonly __file__="$(realpath "${BASH_SOURCE[0]}")"
readonly __name__="$(basename "${__file__}")"
readonly __dir__="$(dirname "${__file__}")"
readonly __tmp__="$(mktemp --directory --tmpdir "${__name__}-XXXX")"
readonly __argv__=("$@")

if [[ -t 0 && -t 1 && -t 2 ]]; then
    readonly __isatty__=true;
else
    readonly __isatty__=false;
fi

### Switch pwd to __dir__ and sanity-check path constants.

cd "${__tmp__}"
test -d "${__owd__}"
test -f "${__file__}"
test -d "${__dir__}"
test -f "${__dir__}/${__name__}"
test -d "${__tmp__}"
cd "${__dir__}"

### Environment variables.

readonly TERM="${TERM=dumb}"
export TERM

if [[ "${CI:-}" == "true" ]]; then
    readonly CI=true
    export CI
else
    readonly CI=false
    export -n CI
fi


### Not implemented.

echo "FATAL: Not implemented."
exit 1
