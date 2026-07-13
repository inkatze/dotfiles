#!/usr/bin/env bash
# Contract-consistency checker for the dotfiles-local review command files
# (panel-*, peer-review). Greps them for cross-file invariants that must stay
# aligned. Runs as a lefthook pre-commit job filtered to
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
# the exact gap the v1-retrospective (research/v1-retrospective.md:89)
# already caught once ("three findings tables" drifted to four undetected).
#
# NOTE: each check below is an explicit if-block, not a `cond && ! grep &&
# err` chain. Under `set -e`, a chain like that exits the script silently
# the moment grep SUCCEEDS (the good case): the short-circuited `&&` list
# evaluates to non-zero as the last command run, and errexit kills the
# script before `err` (or anything after it) ever runs. Bare-loop chains of
# that shape happened not to trip it in testing, but it's fragile either
# way; explicit ifs are unambiguous under set -e.
bucket_files="panel-review.md panel-pairing.md peer-review.md"
bucket_phrases=(
  "three findings tables in fixed order"
  "bucket out of three: Auto-applicable, Needs sign-off, or Needs human judgment"
  "the validated threads as three tables"
)
i=0
for f in $bucket_files; do
  phrase="${bucket_phrases[$i]}"
  i=$((i + 1))
  if [ -f "$CMDS/$f" ]; then
    if ! grep -qF "$phrase" "$CMDS/$f"; then
      err "$f missing expected bucket-count sentence: \"$phrase\""
    fi
    # Guard against the retired bucket being reintroduced under wording the
    # sentence check above wouldn't catch.
    if grep -q 'Agent-resolvable' "$CMDS/$f"; then
      err "$f references the retired Agent-resolvable bucket"
    fi
  fi
done

if [ "$errors" -gt 0 ]; then
  echo ""
  echo "skill-contracts: $errors invariant(s) broken"
  exit 1
fi
echo "skill-contracts: all invariants hold"
