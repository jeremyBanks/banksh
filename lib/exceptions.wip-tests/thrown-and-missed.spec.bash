eval "$(cat "$(dirname "${BASH_SOURCE[0]}")/../../.banksh/lib/exceptions")"

function alpha {
  beta -v2
}

function beta {
  try
    gamma -m "hello"
  catch ValueError
    echo "This can't happen."
  yrt
}

function gamma {
  delta --diffstat
}

function delta {
  throw TypeError: "got a cat when we expected a dog"
}

alpha
