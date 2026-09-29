#!/usr/bin/env bash
# Review-time check that no live instruction file names an external project,
# employer organization or work repository. The names come from the untracked
# machine-local identifier file (the one scripts/gitleaks-identifier-rules.sh
# reads), so this public repo never carries the names it checks for.
#
# Reports file and line only, never the matched name. A missing identifier
# file is a warning, not a pass. Run from the repo root, by hand at task
# review and from skill-contracts-test.sh; it is never a commit gate.
set -euo pipefail

idfile="${IDENTIFIER_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/private-identifiers}"

# Live instruction files, plus the bundle that audits them. Frozen bundles are
# records and stay out of scope.
scope=(
  roles/claude/files/skills
  roles/claude/files/CLAUDE.md
  CLAUDE.md
  specs/claude-instructions
)

if [ ! -f "$idfile" ] || [ ! -r "$idfile" ]; then
  echo "WARN: no readable identifier file at $idfile; the identifier check could not run here" >&2
  exit 0
fi

patterns="$(mktemp)"
trap 'rm -f "$patterns"' EXIT
grep -vE '^[[:space:]]*(#|$)' "$idfile" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' > "$patterns" || true
if [ ! -s "$patterns" ]; then
  echo "WARN: $idfile holds no identifiers; the identifier check could not run here" >&2
  exit 0
fi

paths=()
for p in "${scope[@]}"; do
  if [ -e "$p" ]; then paths+=("$p"); else echo "WARN: $p is not present; not checked" >&2; fi
done
[ "${#paths[@]}" -gt 0 ] || { echo "ERROR: none of the checked paths exist; run from the repo root" >&2; exit 1; }

hits="$(grep -rniI -F -f "$patterns" -- "${paths[@]}" | cut -d: -f1,2 || true)"
if [ -n "$hits" ]; then
  printf '%s\n' "$hits"
  echo "identifier-check: $(printf '%s\n' "$hits" | grep -c .) line(s) name an identifier from $idfile" >&2
  exit 1
fi
echo "identifier-check: no identifier from $idfile in the checked files"
