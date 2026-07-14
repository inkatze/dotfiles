#!/usr/bin/env bash
# Contract-consistency checker for the dotfiles-local review command files
# (panel-review, peer-review). Greps them for cross-file invariants that must
# stay aligned. Runs as a lefthook pre-commit job filtered to
# roles/osx/files/claude/commands/*.md.
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
# panel-review.md carries two anchor sentences, not one: its standalone mode
# declares the bucket count via the "three findings tables" phrasing, and its
# --nested loop (formerly the separate panel-pairing.md, folded in behind the
# --nested flag) declares it via the "bucket out of three" phrasing. Both
# must independently hold in the merged file.
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
)
bucket_files="panel-review.md peer-review.md"
for check in "${bucket_checks[@]}"; do
  f="${check%%|*}"
  phrase="${check#*|}"
  if [ -f "$CMDS/$f" ]; then
    if ! grep -qF "$phrase" "$CMDS/$f"; then
      err "$f missing expected bucket-count sentence: \"$phrase\""
    fi
  fi
done
# Guard against the retired bucket being reintroduced under wording the
# sentence checks above wouldn't catch.
for f in $bucket_files; do
  if [ -f "$CMDS/$f" ] && grep -q 'Agent-resolvable' "$CMDS/$f"; then
    err "$f references the retired Agent-resolvable bucket"
  fi
done

if [ "$errors" -gt 0 ]; then
  echo ""
  echo "skill-contracts: $errors invariant(s) broken"
  exit 1
fi
echo "skill-contracts: all invariants hold"
