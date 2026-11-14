#!/usr/bin/env bash
# Fixture suite for bot-review-decline-route.sh.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
R="$HERE/bot-review-decline-route.sh"
failures=0

# expect <name> <want> <env value, or - for unset> <args...>
expect() {
  local name="$1" want="$2" cfg="$3" got
  shift 3
  if [ "$cfg" = "-" ]; then
    got="$(env -u BOT_REVIEW_PROVEN_DECLINES "$R" "$@")"
  else
    got="$(BOT_REVIEW_PROVEN_DECLINES="$cfg" "$R" "$@")"
  fi
  [ "$got" = "$want" ] || { echo "FAIL $name: want $want, got $got"; failures=$((failures + 1)); }
}

# Default: nothing configured, every decline goes to the operator.
expect default-repro operator - repro "make t" "exit 0"
expect default-test operator - test a_test.sh "case one"
expect default-cite operator - cite roles/x.sh:12
expect default-none operator - none
expect empty-config operator "" cite roles/x.sh:12
expect other-config operator operator cite roles/x.sh:12

# Configured: proven declines settle at mission control.
expect repro mission-control mission-control repro "make t" "exit 0"
expect test mission-control mission-control test a_test.sh "case one"
expect cite mission-control mission-control cite roles/x.sh:12
expect cite-range mission-control mission-control cite roles/x.sh:12-20

# Configured: incomplete proof or a judgment call stays with the operator.
expect repro-no-output operator mission-control repro "make t" ""
expect repro-no-command operator mission-control repro "" "exit 0"
expect test-no-case operator mission-control test a_test.sh
expect cite-no-line operator mission-control cite roles/x.sh
expect cite-prose operator mission-control cite "see the code"
expect judgment operator mission-control none
expect unknown-kind operator mission-control hunch "I think so"

[ "$failures" -eq 0 ] || { echo "$failures failure(s)"; exit 1; }
echo "bot-review-decline-route-test: ok"
