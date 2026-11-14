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
# complete for its kind; anything else, including a judgment call (none) and
# an unset variable, goes to the operator.
set -euo pipefail

kind="${1:-none}"
shift || true

proven=false
case "$kind" in
  repro) [ $# -ge 2 ] && [ -n "${1//[[:space:]]/}" ] && [ -n "${2//[[:space:]]/}" ] && proven=true ;;
  test) [ $# -ge 2 ] && [ -n "${1//[[:space:]]/}" ] && [ -n "${2//[[:space:]]/}" ] && proven=true ;;
  cite) [ $# -ge 1 ] && [[ "$1" =~ ^[^[:space:]:]+:[0-9]+(-[0-9]+)?$ ]] && proven=true ;;
esac

if [ "${BOT_REVIEW_PROVEN_DECLINES:-}" = "mission-control" ] && $proven; then
  echo mission-control
else
  echo operator
fi
