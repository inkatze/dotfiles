#!/usr/bin/env bash
# Routes a /bot-review decline: prints "mission-control" or "operator".
#
#   bot-review-decline-route.sh repro <command> <output>
#   bot-review-decline-route.sh test  <file> <case>
#   bot-review-decline-route.sh cite  <file:line[-line]>
#   bot-review-decline-route.sh none
#
# A decline goes to the supervising mission control only when
# BOT_REVIEW_PROVEN_DECLINES is exactly "mission-control" and the proof is
# complete for its kind: a test file or a cited line must exist inside the
# working directory (symlinks leaving it are refused). Anything else, a
# judgment call (none) and an unset variable included, goes to the operator.
set -euo pipefail

kind="${1:-none}"
shift || true

inside() {
  local real root
  root="$(pwd -P)"
  real="$(realpath -- "$1" 2> /dev/null)" || return 1
  [[ "$root" != / && "$real" == "$root"/* && -f "$real" ]]
}

proven=false
case "$kind" in
  repro)
    [ $# -ge 2 ] && [ -n "${1//[[:space:]]/}" ] && [ -n "${2//[[:space:]]/}" ] && proven=true
    ;;
  test)
    [ $# -ge 2 ] && [ -n "${2//[[:space:]]/}" ] && inside "$1" && proven=true
    ;;
  cite)
    if [ $# -ge 1 ] && [[ "$1" =~ ^([^[:space:]:]+):([0-9]{1,9})(-([0-9]{1,9}))?$ ]]; then
      file="${BASH_REMATCH[1]}" first="${BASH_REMATCH[2]}" last="${BASH_REMATCH[4]:-${BASH_REMATCH[2]}}"
      if inside "$file" && [ "$first" -ge 1 ] && [ "$first" -le "$last" ] \
        && [ "$last" -le "$(awk 'END { print NR }' < "$file")" ]; then
        proven=true
      fi
    fi
    ;;
esac

if [ "${BOT_REVIEW_PROVEN_DECLINES:-}" = "mission-control" ] && $proven; then
  echo mission-control
else
  echo operator
fi
