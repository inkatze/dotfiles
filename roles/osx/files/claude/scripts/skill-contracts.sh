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

# Three-bucket presentation contract (Finding Categorization)
for f in panel-review.md panel-pairing.md peer-review.md; do
  [ -f "$CMDS/$f" ] && ! grep -qE 'three.*table|three bucket|three:.*Auto-applicable' "$CMDS/$f" \
    && err "$f missing three-bucket presentation reference"
done

if [ "$errors" -gt 0 ]; then
  echo ""
  echo "skill-contracts: $errors invariant(s) broken"
  exit 1
fi
echo "skill-contracts: all invariants hold"
