eval "$(cat "$(dirname "${BASH_SOURCE[0]}")/../exceptions.bash")"

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
