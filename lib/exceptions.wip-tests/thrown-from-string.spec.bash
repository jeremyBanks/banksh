eval "$(cat -- "$(dirname "${BASH_SOURCE[0]}")/../../.banksh/lib/exceptions")"

function main {
  declare s
  s="hello $(get-name)"
  echo "$s"
}

function get-name {
  throw NotImplementedError: "a girl has no name"
}

main
