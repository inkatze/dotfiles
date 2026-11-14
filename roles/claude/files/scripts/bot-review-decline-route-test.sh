#!/usr/bin/env bash
# Fixture suite for bot-review-decline-route.sh.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
R="$HERE/bot-review-decline-route.sh"
failures=0

work="$(mktemp -d)"
links="$(mktemp -d)"
trap 'rm -rf "$work" "$links"' EXIT
cd "$work"
work="$(pwd -P)"
cd "$work"
printf 'one\ntwo\nthree\n' > x.sh
printf '#!/bin/sh\n' > a_test.sh
printf 'one\ntwo' > nonl.sh
mkdir sub
printf 'o\n' > "$links/outside.txt"
ln -s "$links/outside.txt" link.sh
ln -s ../x.sh sub/up.sh
printf 'e\n' > 'a=b.sh'
printf 'a\n' > sub/y.sh

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
expect default-cite operator - cite x.sh:2
expect default-none operator - none
expect empty-config operator "" cite x.sh:2
expect other-config operator operator cite x.sh:2

# Configured: proven declines settle at mission control.
expect repro mission-control mission-control repro "make t" "exit 0"
expect test mission-control mission-control test a_test.sh "case one"
expect cite mission-control mission-control cite x.sh:2
expect cite-range mission-control mission-control cite x.sh:1-3

# Configured: incomplete proof or a judgment call stays with the operator.
expect cite-no-trailing-newline mission-control mission-control cite nonl.sh:2
expect cite-subdir mission-control mission-control cite sub/y.sh:1
expect cite-absolute-outside operator mission-control cite "$links/outside.txt:1"
expect cite-parent operator mission-control cite ../x.sh:1
expect cite-embedded-parent mission-control mission-control cite sub/../x.sh:1
expect cite-overflow operator mission-control cite x.sh:99999999999999999999
expect test-absolute-inside mission-control mission-control test "$work/a_test.sh" "case one"
expect cite-symlink-out operator mission-control cite link.sh:1
expect cite-symlink-inside mission-control mission-control cite sub/up.sh:1
expect test-symlink-out operator mission-control test link.sh "case one"
expect cite-equals-name mission-control mission-control cite a=b.sh:1
expect cite-directory operator mission-control cite sub:1
expect test-directory operator mission-control test sub "case one"
expect repro-one-arg operator mission-control repro "make t"
expect cite-no-arg operator mission-control cite
expect repro-blank operator mission-control repro " " " "
expect test-missing-file operator mission-control test nope_test.sh "case one"
expect test-blank-case operator mission-control test a_test.sh " "
expect cite-missing-file operator mission-control cite nope.sh:1
expect cite-past-end operator mission-control cite x.sh:4
expect cite-zero operator mission-control cite x.sh:0
expect cite-reversed operator mission-control cite x.sh:3-1
expect cite-bad-range operator mission-control cite x.sh:1-
expect var-case operator Mission-Control cite x.sh:1
expect var-space operator "mission-control " cite x.sh:1
expect no-args operator mission-control
expect repro-no-output operator mission-control repro "make t" ""
expect repro-no-command operator mission-control repro "" "exit 0"
expect test-no-case operator mission-control test a_test.sh
expect cite-no-line operator mission-control cite x.sh
expect cite-prose operator mission-control cite "see the code"
expect judgment operator mission-control none
expect unknown-kind operator mission-control hunch "I think so"


# A checkout reached through a symlinked parent still resolves its own files.
ln -s "$work" "$links/l"
if ! (cd "$links/l" && [ "$(BOT_REVIEW_PROVEN_DECLINES=mission-control "$R" cite x.sh:1)" = mission-control ]); then
  echo "FAIL symlinked-cwd"
  failures=$((failures + 1))
fi
rm -f "$links/l"
[ "$failures" -eq 0 ] || { echo "$failures failure(s)"; exit 1; }
echo "bot-review-decline-route-test: ok"
