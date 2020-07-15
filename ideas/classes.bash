#!/bin/bash
set -euo pipefail
shopt -s inherit_errexit compat"${BASH_COMPAT=42}"

test-identifier() {

}

declare-instance() {
  declare this="$1"
  test-identifier "$this"
  declare className="$1"
  test-identifier "$className"

  declare -g "$this"="<$this, instance of $className>"


  declare this
}

drop() {

}

declare-class Channel

Channel.__init__() {
  
}

Channel.__del__() {
  
}

Channel.f() {

}

Channel?() {
  // instance of check
}