#!/usr/bin/env bash
# Contract-consistency checker for the dotfiles-local review command files
# (panel-review, peer-review, copilot-review). Greps them for cross-file
# invariants that must stay aligned: the three-bucket presentation contract,
# the panel-pairing/copilot-pairing retirement into --nested, and
# copilot-review's mark-ready confirmation gate. Runs as a lefthook
# pre-commit job filtered to roles/osx/files/claude/commands/*.md.
#
# The spec-driven pipeline skills (orchestrate, execute-task, spec-draft,
# spec-kickoff, polish, self-review, resume) moved to the planwright plugin,
# which carries its own contract tests; only the review commands that stay in
# this repo are checked here.
set -euo pipefail

CMDS="roles/osx/files/claude/commands"
errors=0

err() { echo "ERROR: $1"; errors=$((errors + 1)); }

# Three-bucket presentation contract (Finding Categorization). Anchored to
# each file's own specific declarative sentence rather than a shared
# alternation-regex across files: a shared regex lets an unrelated match
# elsewhere in the same file (e.g. "three-pass" validation prose) mask a real
# regression in the sentence that actually declares the bucket count. This is
# the exact gap the v1-retrospective (specs/pair-flow/research/v1-retrospective.md:89)
# already caught once ("three findings tables" drifted to four undetected).
#
# panel-review.md carries two anchor sentences, not one, both inside the
# shared Steps 1-6 pipeline that standalone and --nested both run identically
# (step 5's "bucket out of three" phrasing and step 6's "three findings
# tables" phrasing); neither is nested-only. copilot-review.md carries a
# third, analogous anchor for its own adjacent-findings output ("Three
# adjacent-findings tables"). All three must independently hold.
#
# NOTE: each check below is an explicit if-block, not a `cond && ! grep &&
# err` chain. Under `set -e`, a chain like that exits the script silently
# the moment grep SUCCEEDS (the good case): the short-circuited `&&` list
# evaluates to non-zero as the last command run, and errexit kills the
# script before `err` (or anything after it) ever runs. Bare-loop chains of
# that shape happened not to trip it in testing, but it's fragile either
# way; explicit ifs are unambiguous under set -e.
bucket_checks=(
  "panel-review.md|three findings tables in fixed order"
  "panel-review.md|bucket out of three: Auto-applicable, Needs sign-off, or Needs human judgment"
  "peer-review.md|the validated threads as three tables"
  "copilot-review.md|Three adjacent-findings tables"
)
# Derived from bucket_checks, not hand-maintained, so the Agent-resolvable
# guard below can never drift out of sync with the files bucket_checks
# actually covers (a malformed entry is reported by the main loop below;
# this pass just skips it rather than double-reporting).
bucket_files=""
for check in "${bucket_checks[@]}"; do
  case "$check" in
    *'|'*) f="${check%%|*}" ;;
    *) continue ;;
  esac
  case " $bucket_files " in
    *" $f "*) ;;
    *) bucket_files="$bucket_files $f" ;;
  esac
done
for check in "${bucket_checks[@]}"; do
  case "$check" in
    *'|'*) ;;
    *) err "malformed bucket_checks entry (missing '|' separator): \"$check\""; continue ;;
  esac
  f="${check%%|*}"
  phrase="${check#*|}"
  if [ -f "$CMDS/$f" ]; then
    if ! grep -qF "$phrase" "$CMDS/$f"; then
      err "$f missing expected bucket-count sentence: \"$phrase\""
    fi
  else
    err "$f referenced in bucket_checks but does not exist at $CMDS/$f"
  fi
done
# Guard against the retired bucket being reintroduced under wording the
# sentence checks above wouldn't catch.
for f in $bucket_files; do
  if [ -f "$CMDS/$f" ] && grep -q 'Agent-resolvable' "$CMDS/$f"; then
    err "$f references the retired Agent-resolvable bucket"
  fi
done

# Retired-files guard. panel-pairing.md and copilot-pairing.md were folded
# into panel-review.md / copilot-review.md's --nested flag; if either
# reappears, the fold either regressed or is being silently duplicated.
for retired in panel-pairing.md copilot-pairing.md; do
  if [ -f "$CMDS/$retired" ]; then
    err "$retired exists but was retired into --nested; remove it or update this guard if reintroducing it is intentional"
  fi
done

# Mark-ready safety anchor. copilot-review.md's nested loop may flip a PR
# ready only at convergence and only after an explicit per-run confirmation;
# this is the one PR-lifecycle mutation the loop is allowed, so its two
# guarding sentences must not silently drift or disappear.
mark_ready_checks=(
  "This confirmation-gated ready-flip is the only PR-lifecycle action this loop takes, and only on this exit path."
  "Never automatically, never on a diminishing-returns/stop-condition/iteration-cap exit, and never for create or merge"
)
if [ -f "$CMDS/copilot-review.md" ]; then
  for phrase in "${mark_ready_checks[@]}"; do
    if ! grep -qF "$phrase" "$CMDS/copilot-review.md"; then
      err "copilot-review.md missing expected mark-ready safety sentence: \"$phrase\""
    fi
  done
else
  err "copilot-review.md referenced by mark_ready_checks but does not exist at $CMDS/copilot-review.md"
fi

if [ "$errors" -gt 0 ]; then
  echo ""
  echo "skill-contracts: $errors invariant(s) broken"
  exit 1
fi
echo "skill-contracts: all invariants hold"
