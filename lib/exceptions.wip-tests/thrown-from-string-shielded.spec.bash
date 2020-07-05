eval "$(cat -- "$(dirname "${BASH_SOURCE[0]}")/../../.banksh/lib/exceptions")"

function main {
  shield echo "hello $(get-name)"
}

function get-name {
  throw NotImplementedError: "a girl has no name"
}

main
