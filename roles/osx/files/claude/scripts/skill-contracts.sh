#!/usr/bin/env bash
# Contract-consistency checker for the dotfiles-local review skill files
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

# D-32: branch naming pattern (pair-flow/<spec>/task-<ids>) parsed by the
# kickoff-brief detection in /panel-pairing.
for f in panel-pairing.md; do
  [ -f "$CMDS/$f" ] && ! grep -q 'pair-flow/.*task-' "$CMDS/$f" \
    && err "$f missing D-32 branch naming pattern"
done

# Four-bucket presentation contract (Finding Categorization)
for f in panel-pairing.md peer-review.md; do
  [ -f "$CMDS/$f" ] && ! grep -qE 'four.table|four bucket|four:.*Auto-applicable' "$CMDS/$f" \
    && err "$f missing four-bucket presentation reference"
done

# pair-flow-config.sh repo-class in skills that use it
for f in panel-pairing.md peer-review.md; do
  [ -f "$CMDS/$f" ] && ! grep -q 'pair-flow-config\.sh' "$CMDS/$f" \
    && err "$f missing pair-flow-config.sh reference"
done

if [ "$errors" -gt 0 ]; then
  echo ""
  echo "skill-contracts: $errors invariant(s) broken"
  exit 1
fi
echo "skill-contracts: all invariants hold"
