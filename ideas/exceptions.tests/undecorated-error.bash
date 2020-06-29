eval "$(cat "$(dirname "${BASH_SOURCE[0]}")/../exceptions.bash")"

function alpha {
  beta 
}

function beta {
  gamma
}

function gamma {
  delta
}

function delta {
  ten-four
}

alpha
