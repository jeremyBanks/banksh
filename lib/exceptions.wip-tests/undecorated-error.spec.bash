eval "$(cat "$(dirname "${BASH_SOURCE[0]}")/../../.banksh/lib/exceptions")"

function alpha {
  beta -v2
}

function beta {
  gamma -m "hello"
}

function gamma {
  delta --diffstat
}

function delta {
  ten-four @roger
}

alpha
