eval "$(cat -- "$(dirname "${BASH_SOURCE[0]}")/../../.banksh/lib/exceptions")"

function main {
  shield echo "hello $(get-name) $(get-name) $(get-name) $(true)"
  echo "salut"
  shield echo "goodbye $(shield get-name)" "$(shield get-name)" "$(shield get-name)" "$(shield true)"
  shield echo "goodbye $(shield get-name) $(shield get-name) $(shield get-name) $(shield true)"
  shield echo goodbye $(shield get-name) $(shield get-name) $(shield get-name) $(shield true)
}

function get-name {
  throw NotImplementedError: "a girl has no name"
}

main
