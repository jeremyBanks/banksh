eval "$(cat "$(dirname "${BASH_SOURCE[0]}")/../../.banksh/lib/exceptions")"

echo "hello world"

echo "hello underworld" >&2

exit 42
