#!/bin/bash
set -euo pipefail;
: "${MERKLE_TARGET=$(dirname "${BASH_SOURCE}")/..}";

pushd "${MERKLE_TARGET}";

git --no-pager log --format=raw --graph --decorate -n 2;
echo;

if [[ ! "${MERKLE_NO_CONFIRM:-}" =~ ^[Yy]$ ]]; then
  read -p "$(tput bold)$(tput setaf 1)Press Y to normalize the merkle tree. Press N to quit. $(tput smul)" -n 1 -r;
  echo "$(tput sgr 0)";
  echo;
  if [[ ! "${REPLY}" =~ ^[Yy]$ ]]; then
      exit 1;
  fi
fi

env='export GIT_HEIGHT="$(git rev-list --count "${GIT_COMMIT:-HEAD}")" ;\
  export GIT_COMMITTER_TIMESTAMP="$((1577836800 + (20 + 60 * 20) * (${GIT_HEIGHT} - 1) ))" ;\
  export GIT_COMMITTER_DATE="$(date -ud @"${GIT_COMMITTER_TIMESTAMP}")" ;\
  export GIT_COMMITTER_NAME="user" ;\
  export GIT_COMMITTER_EMAIL="\<user@localhost\>" ;\
  export GIT_AUTHOR_TIMESTAMP="${GIT_COMMITTER_TIMESTAMP}" ;\
  export GIT_AUTHOR_DATE="${GIT_COMMITTER_DATE}" ;\
  export GIT_AUTHOR_NAME="${GIT_COMMITTER_NAME}" ;\
  export GIT_AUTHOR_EMAIL="${GIT_COMMITTER_EMAIL}" ;\
  export GIT_TREE_HASH="$(git rev-parse --short=8 ${GIT_COMMIT:-HEAD}^{tree})" ;\
  export GIT_MESSAGE="$(printf r%s:\ %s "$(git rev-list --count ${GIT_COMMIT:-HEAD})" "$(git write-tree | python3 -c '"'"'print(" ".join(list(filter(bool, (dict(a="alfa", b="bravo", c="charlie", d="delta", e="echo", f="foxtrot", **{"0": "zero", "1": "one", "2": "two", "3": "three", "4": "four", "5": "five", "6": "six", "7": "seven", "8": "eight", "9": "nine"}).get(c, "") for c in __import__("sys").stdin.read().lower())))[:4]))'"'"')")" ;\
  true';

FILTER_BRANCH_SQUELCH_WARNING=true git filter-branch --force --env-filter "${env}" --msg-filter "${env}; echo \${GIT_MESSAGE}" "$@" || echo "I hope that wasn't an error!" 1>&2;

echo;
git --no-pager log --format=raw --graph --decorate -n 2;