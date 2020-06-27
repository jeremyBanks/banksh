# Enable typical Bash error handling.
set -euo pipefail

# Ensure a known-compatible version of Bash.
(( "${BASH_VERSINFO[0]}" >= 4 )) && readonly BASH_COMPAT=4.2

