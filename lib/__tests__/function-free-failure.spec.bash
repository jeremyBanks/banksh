eval "$(cat "$(dirname "${BASH_SOURCE[0]}")/../exceptions")"

echo "hello world"

echo "hello underworld" >&2

exit 42
