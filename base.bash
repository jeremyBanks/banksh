: base.bash script framework
# shellcheck shell=bash

{ # Check preconditions and set Bash settings.
    if [[ "${BASH_VERSINFO[0]:-0}" -le 3 ]]; then
        echo "FATAL: bash>=4.2 required, but using: $("$(command -v "$(ps -cp "$$" -o command=)")" --version)"
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

    set -o monitor -o pipefail -o errexit -o errtrace -o functrace -o nounset -o noclobber
    shopt -s nullglob globstar
    shopt -u sourcepath
}

{ # Declare global constants.
    readonly __owd__="$(realpath "$(pwd)")"
    readonly __file__="$(realpath "${BASH_SOURCE[0]}")"
    readonly __name__="$(basename "${__file__}")"
    readonly __dir__="$(dirname "${__file__}")"
    readonly __tmp__="$(mktemp --directory --tmpdir "${__name__}$(date +@%Y%m%d%H%M@XXXX)")"
    readonly __argv__=("$@")
}

{ # Set working directory and sanity-check paths.
    cd "${__tmp__}"
    test -d "${__owd__}"
    test -f "${__file__}"
    test -d "${__dir__}"
    test -f "${__dir__}/${__name__}"
    test -d "${__tmp__}"
    cd "${__dir__}"
}

{ # Set environment variables.
    readonly TERM="${TERM=dumb}"
    export TERM

    if [[ "${CI:-}" == "true" ]]; then
        readonly CI=true
        export CI
    else
        readonly CI=false
        export -n CI
    fi
}

{ # Declare internal functions and state.
    function ::entry-point() {
        if [[ $1 != 0 ]]; then
            printf "FATAL: global initialization failed"
            return "$1"
        fi

        declare -p | grep '__='
        print "FATAL: not implemented"

        return 2
    }

    function ::exit-point() {   
        rm -rf "${__tmp__}"

        exit "$1"
    }
}

{ # Declare global/public functions.
    function print() {
        echo "$@"
    }
}

{ # Declare built-in flags and commands.
    command::help() {
        : not implemented
    }

    flag::verbose() {
        : not implemented
    }

    flag::quiet() {
        : not implemented
    }
}

{ # Set trap for automatic deferred entry point.
    # shellcheck disable=2154
    trap '( status=$?; ::entry-point $status || status=$?; ::exit-point $status; )' EXIT
}
