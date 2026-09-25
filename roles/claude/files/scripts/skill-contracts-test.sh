#!/usr/bin/env bash
# Fixture tests for skill-contracts.sh: prove each check class actually
# fires when its anchor drifts, and stays quiet on benign edits. The
# checker's body comments document two historical ways grep-based checks
# silently no-op (a shared alternation regex masked by an unrelated match,
# and a `set -e && `-chain that dies before err runs); this suite is the
# negative side. Each failing case copies the real tracked inputs into a
# temp tree, plants exactly one drift, verifies the drift actually changed
# the tree (a fixture whose pattern no longer matches must fail as "did not
# apply", not masquerade as a checker regression), and asserts the checker
# exits non-zero mentioning the expected message. Passing cases plant a
# benign edit and assert the checker stays green.
#
# Runs from the dotfiles checkout only (pre-commit via lefthook, and CI);
# mutations use perl -pi for BSD/GNU portability across the CI runners.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
# Through the materialized ~/.claude/scripts symlink this resolves outside
# the repo; refuse with a hint instead of dying on a bare cp error.
[ -f "$ROOT/lefthook.yml" ] || {
  echo "skill-contracts-test: must run from the dotfiles checkout (ROOT resolved to $ROOT)"
  exit 1
}
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

teardown() { rm -rf "$tmp" || true; tmp=""; }
trap '[ -n "$tmp" ] && rm -rf "$tmp"' EXIT

run_checker() { (cd "$tmp" && bash roles/claude/files/scripts/skill-contracts.sh); }

# Tree fingerprint, used to prove a mutation actually changed something.
# Paths in this tree are controlled (no whitespace), so plain xargs is safe.
tree_sum() {
  (cd "$tmp" && find roles -type f | LC_ALL=C sort | xargs cksum | cksum)
}

# The unmutated tree must pass; without that every case below is
# meaningless, so a baseline failure aborts instead of letting ten cases
# "pass" against a checker that rejects everything.
baseline() {
  setup
  local out
  if ! out="$(run_checker 2>&1)"; then
    echo "FAIL baseline: checker rejects the tracked files: $out"
    teardown
    echo "skill-contracts-test: baseline failed; aborting"
    exit 1
  fi
  teardown
}

# expect_fail <name> <mutation command run from $tmp> <expected message fragment>
expect_fail() {
  local name="$1" mutation="$2" fragment="$3" out pre post
  setup
  pre="$(tree_sum)"
  if ! (cd "$tmp" && eval "$mutation"); then
    echo "FAIL $name: mutation command errored"
    failures=$((failures + 1))
    teardown
    return
  fi
  post="$(tree_sum)"
  if [ "$pre" = "$post" ]; then
    echo "FAIL $name: mutation did not change the tree (stale fixture: its pattern no longer matches the tracked files)"
    failures=$((failures + 1))
    teardown
    return
  fi
  if out="$(run_checker 2>&1)"; then
    echo "FAIL $name: checker passed after mutation"
    failures=$((failures + 1))
  elif ! printf '%s' "$out" | grep -qF "$fragment"; then
    echo "FAIL $name: expected message containing \"$fragment\", got: $out"
    failures=$((failures + 1))
  fi
  teardown
}

# expect_pass <name> <benign mutation run from $tmp>
expect_pass() {
  local name="$1" mutation="$2" out pre post
  setup
  pre="$(tree_sum)"
  if ! (cd "$tmp" && eval "$mutation"); then
    echo "FAIL $name: mutation command errored"
    failures=$((failures + 1))
    teardown
    return
  fi
  post="$(tree_sum)"
  if [ "$pre" = "$post" ]; then
    echo "FAIL $name: mutation did not change the tree (stale fixture)"
    failures=$((failures + 1))
    teardown
    return
  fi
  if ! out="$(run_checker 2>&1)"; then
    echo "FAIL $name: checker rejected a benign edit: $out"
    failures=$((failures + 1))
  fi
  teardown
}

CMDS="roles/claude/files/commands"

baseline

# --- bucket_checks: one fixture per anchor ---
expect_fail bucket-panel-tables \
  "perl -pi -e 's/three findings tables in fixed order/four findings tables in fixed order/' $CMDS/panel-review.md" \
  "missing expected bucket-count sentence"

expect_fail bucket-panel-out-of-three \
  "perl -pi -e 's/bucket out of three: Auto-applicable, Needs sign-off, or Needs human judgment/bucket out of four/' $CMDS/panel-review.md" \
  "missing expected bucket-count sentence"

expect_fail bucket-peer-tables \
  "perl -pi -e 's/the validated threads as three tables/the validated threads as tables/' $CMDS/peer-review.md" \
  "missing expected bucket-count sentence"

expect_fail bucket-copilot-adjacent \
  "perl -pi -e 's/Three adjacent-findings tables/Adjacent-findings tables/' $CMDS/copilot-review.md" \
  "missing expected bucket-count sentence"

expect_fail bucket-bot-review-tables \
  "perl -pi -e 's/Present all three tables, in fixed order/Present the tables/' $CMDS/bot-review.md" \
  "missing expected bucket-count sentence"

# --- retired-bucket sweep: panel (original), copilot (bucket_files), and
# code-review (its own separate guard outside bucket_files) ---
expect_fail retired-bucket \
  "echo 'Agent-resolvable' >> $CMDS/panel-review.md" \
  "retired Agent-resolvable bucket"

expect_fail retired-bucket-copilot \
  "echo 'Agent-resolvable' >> $CMDS/copilot-review.md" \
  "copilot-review.md references the retired Agent-resolvable bucket"

expect_fail retired-bucket-code-review \
  "echo 'Agent-resolvable' >> $CMDS/code-review.md" \
  "code-review.md references the retired Agent-resolvable bucket"

# A missing jq must be reported as missing, not as every config being invalid.
setup
nojq="$(mktemp -d)"
for t in bash grep tr cat sort cksum find xargs basename dirname; do
  p="$(command -v "$t")" && ln -s "$p" "$nojq/$t"
done
if out="$(cd "$tmp" && PATH="$nojq" bash roles/claude/files/scripts/skill-contracts.sh 2>&1)"; then
  echo "FAIL missing-jq: checker passed without jq"; failures=$((failures + 1))
elif ! printf '%s' "$out" | grep -qF "jq is required"; then
  echo "FAIL missing-jq: expected \"jq is required\", got: $out"; failures=$((failures + 1))
elif printf '%s' "$out" | grep -qF "is not valid JSON"; then
  echo "FAIL missing-jq: still blamed the config"; failures=$((failures + 1))
fi
rm -rf "$nojq"
teardown

expect_fail example-config-json \
  "echo 'not json' >> $CMDS/bot-review.config.example.json" \
  "is not valid JSON"

expect_fail retired-bucket-bot-review \
  "echo 'Agent-resolvable' >> $CMDS/bot-review.md" \
  "bot-review.md references the retired Agent-resolvable bucket"

expect_fail retired-file \
  "touch $CMDS/panel-pairing.md" \
  "was retired into --nested"

# --- retired-backend sweep: a command file and the tracked CLAUDE.md, since
# the sweep covers both ---
expect_fail retired-backend-name \
  "echo 'qwen-coder' >> $CMDS/panel-review.md" \
  "retired backend name"

expect_fail retired-backend-name-global \
  "echo 'OLLAMA_BASE_URL' >> roles/claude/files/CLAUDE.md" \
  "retired backend name"

expect_fail mark-ready \
  "perl -pi -e 's/This confirmation-gated ready-flip is the only PR-lifecycle action this loop takes, and only on this exit path\\.//' $CMDS/copilot-review.md" \
  "mark-ready safety sentence"

# --- bot-review's own single-mutation safety anchors ---
expect_fail bot-review-safety-nested-apply \
  "perl -pi -e 's/Never apply the code change in this bucket while nested\\.//' $CMDS/bot-review.md" \
  "bot-review.md missing expected safety sentence"

expect_fail bot-review-safety-never-mutate \
  "perl -pi -e 's/force-push, push to a protected branch, mark the PR ready, or merge/land whatever it likes/' $CMDS/bot-review.md" \
  "bot-review.md missing expected safety sentence"

expect_fail bot-review-safety-no-speculative-label \
  "perl -pi -e 's/Do not add the opt-in label speculatively//' $CMDS/bot-review.md" \
  "bot-review.md missing expected safety sentence"

# --- require_phrases' missing-file branch, shared by all its callers ---
expect_fail require-phrases-missing-file \
  "rm $CMDS/code-review.md" \
  "code-review.md referenced by severity_checks but does not exist"

# --- severity tiers: a word-presence anchor and the order-declaring sentence ---
expect_fail severity-tier \
  "perl -pi -e 's/\\*\\*Nits\\*\\*/**Notes**/g' $CMDS/code-review.md" \
  "missing expected severity tier"

expect_fail severity-order \
  "perl -pi -e 's/each as its own table in fixed order: Blockers, Concerns, Suggestions, Nits/as tables/' $CMDS/code-review.md" \
  "missing expected severity tier"

expect_fail no-bucket-sentence \
  "perl -pi -e 's/does \\*\\*not\\*\\* use the three-bucket categorization/uses the three-bucket categorization/' $CMDS/code-review.md" \
  "no-bucket-categorization sentence"

# --- option-set literals: both copies of the contract ---
expect_fail option-set \
  "perl -pi -e 's{Post inline / Post as PR-level / Defer to follow-up / Dismiss}{Post / Defer}g' roles/claude/files/CLAUDE.md" \
  "CLAUDE.md missing /code-review option-set literal"

expect_fail option-set-code-review \
  "perl -pi -e 's{Post all inline / Post all as PR-level / Defer all to follow-up / Dismiss all / Pick individually}{Post all / Skip all}g' $CMDS/code-review.md" \
  "code-review.md missing option-set literal"

# --- resolver sync: both sides of the mirror ---
expect_fail resolver-sync \
  "perl -pi -e 's/grep -q panela/grep -q renamed/' $CMDS/code-review.md" \
  "missing shared resolver line"

expect_fail resolver-sync-panel \
  "perl -pi -e 's/grep -q panela/grep -q renamed/' $CMDS/panel-review.md" \
  "missing shared resolver line"

# --- submit gate: the single-line phrase, the hard-wrapped phrase the
# whitespace normalization exists for, and a reflow that must stay green ---
expect_fail submit-gate \
  "perl -0pi -e 's/never choose approval on my behalf/choose approval freely/' $CMDS/code-review.md" \
  "missing expected submit-gate sentence"

expect_fail submit-gate-wrapped \
  "perl -0pi -e 's/never\\s+submit\\s+any\\s+review\\s+without\\s+an\\s+explicitly\\s+chosen\\s+verdict/submit whatever/s' $CMDS/code-review.md" \
  "missing expected submit-gate sentence"

expect_pass submit-gate-reflow \
  "perl -0pi -e 's/explicitly chosen\\s+verdict/explicitly\\nchosen verdict/s' $CMDS/code-review.md"

# --- Slack contract: heading resolution and the sign-off shapes ---
expect_fail slack-heading \
  "perl -pi -e 's/^## Slack Notifications \\(review workflows\\)\$/## Slack Notes/' roles/claude/files/CLAUDE.md" \
  "no such heading exists"

expect_fail signoff-decoration \
  "perl -0pi -e 's/– clanky\\n/– clanky the bot\\n/' $CMDS/code-review.md" \
  "decoration after clanky"

expect_fail signoff-wrong-dash \
  "perl -0pi -e 's/– clanky/— clanky/' $CMDS/code-review.md" \
  "wrong dash"

expect_fail signoff-missing \
  "perl -0pi -e 's/^– clanky[ \\t]*\$//mg' $CMDS/peer-review.md" \
  "carries no"

# --- file-missing guards ---
expect_fail missing-file \
  "rm $CMDS/peer-review.md" \
  "does not exist"

if [ "$failures" -gt 0 ]; then
  echo ""
  echo "skill-contracts-test: $failures case(s) failed"
  exit 1
fi
echo "skill-contracts-test: all cases pass"
