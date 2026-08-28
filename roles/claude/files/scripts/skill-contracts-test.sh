#!/usr/bin/env bash
# Fixture tests for skill-contracts.sh: prove each check class actually
# fails when its anchor drifts. The checker is all positive grep
# assertions, and its own header documents two historical ways such checks
# silently no-op; this suite is the negative side. Each case copies the
# real tracked inputs into a temp tree, plants exactly one drift, and
# asserts the checker exits non-zero mentioning the expected message.
#
# Runs in CI (see .github/workflows/test.yml); mutations use perl -pi for
# BSD/GNU portability, since the CI runners are macOS.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
failures=0
tmp=""

setup() {
  tmp="$(mktemp -d -t skill-contracts-test.XXXXXX)"
  mkdir -p "$tmp/roles/claude/files/scripts"
  cp -r "$ROOT/roles/claude/files/commands" "$tmp/roles/claude/files/"
  cp "$ROOT/roles/claude/files/CLAUDE.md" "$tmp/roles/claude/files/"
  cp "$ROOT/roles/claude/files/scripts/skill-contracts.sh" \
    "$tmp/roles/claude/files/scripts/"
}

teardown() { rm -rf "$tmp"; tmp=""; }
trap '[ -n "$tmp" ] && rm -rf "$tmp"' EXIT

run_checker() { (cd "$tmp" && bash roles/claude/files/scripts/skill-contracts.sh); }

# The unmutated tree must pass, otherwise every case below is meaningless.
baseline() {
  setup
  local out
  if ! out="$(run_checker 2>&1)"; then
    echo "FAIL baseline: checker rejects the tracked files: $out"
    failures=$((failures + 1))
  fi
  teardown
}

# expect_fail <name> <mutation command run from $tmp> <expected message fragment>
expect_fail() {
  local name="$1" mutation="$2" fragment="$3" out
  setup
  (cd "$tmp" && eval "$mutation")
  if out="$(run_checker 2>&1)"; then
    echo "FAIL $name: checker passed after mutation"
    failures=$((failures + 1))
  elif ! printf '%s' "$out" | grep -qF "$fragment"; then
    echo "FAIL $name: expected message containing \"$fragment\", got: $out"
    failures=$((failures + 1))
  fi
  teardown
}

CMDS="roles/claude/files/commands"

baseline

expect_fail bucket-sentence \
  "perl -pi -e 's/three findings tables in fixed order/four findings tables in fixed order/' $CMDS/panel-review.md" \
  "missing expected bucket-count sentence"

expect_fail retired-bucket \
  "echo 'Agent-resolvable' >> $CMDS/panel-review.md" \
  "retired Agent-resolvable bucket"

expect_fail retired-file \
  "touch $CMDS/panel-pairing.md" \
  "was retired into --nested"

expect_fail mark-ready \
  "perl -pi -e 's/This confirmation-gated ready-flip is the only PR-lifecycle action this loop takes, and only on this exit path\\.//' $CMDS/copilot-review.md" \
  "mark-ready safety sentence"

expect_fail severity-tier \
  "perl -pi -e 's/\\*\\*Nits\\*\\*/**Notes**/g' $CMDS/code-review.md" \
  "missing expected severity tier"

expect_fail no-bucket-sentence \
  "perl -pi -e 's/does \\*\\*not\\*\\* use the three-bucket categorization/uses the three-bucket categorization/' $CMDS/code-review.md" \
  "no-bucket-categorization sentence"

expect_fail option-set \
  "perl -pi -e 's{Post inline / Post as PR-level / Defer to follow-up / Dismiss}{Post / Defer}g' roles/claude/files/CLAUDE.md" \
  "CLAUDE.md missing /code-review option-set literal"

expect_fail resolver-sync \
  "perl -pi -e 's/grep -q panela/grep -q renamed/' $CMDS/code-review.md" \
  "missing shared resolver line"

expect_fail submit-gate \
  "perl -0pi -e 's/never choose approval on my behalf/choose approval freely/' $CMDS/code-review.md" \
  "missing expected submit-gate sentence"

expect_fail signoff-decoration \
  "perl -pi -e 's/^– clanky\$/– clanky the bot/' $CMDS/code-review.md" \
  "wrong dash or a decoration"

if [ "$failures" -gt 0 ]; then
  echo ""
  echo "skill-contracts-test: $failures case(s) failed"
  exit 1
fi
echo "skill-contracts-test: all cases pass"
