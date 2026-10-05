#!/usr/bin/env bash
# Review-time check that no live instruction file names an external project,
# employer organization or work repository. The names come from the untracked
# machine-local identifier file (the one scripts/gitleaks-identifier-rules.sh
# reads), so this public repo never carries the names it checks for.
#
# Reports file and line only, never the matched name. A missing identifier
# file is a warning, not a pass. Run from the repo root, by hand at task
# review and from skill-contracts-test.sh; it is never a commit gate.
# Exit 1 means hits; exit 2 means the check could not run as asked.
set -euo pipefail

idfile="${IDENTIFIER_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/private-identifiers}"

# Live instruction files and the templates rendered beside them, the docs/
# notes that hold their relocated rationale, and the bundles that specify or
# audit them. Frozen bundles are records and stay out of scope.
scope=(
  roles/claude/files/skills
  roles/claude/files/planwright
  roles/claude/files/CLAUDE.md
  CLAUDE.md
  docs
  specs/claude-instructions
  specs/review-skills
)

if [ ! -e "$idfile" ]; then
  echo "WARN: no identifier file at $idfile; the identifier check could not run here" >&2
  exit 0
fi
if [ ! -f "$idfile" ] || [ ! -r "$idfile" ]; then
  echo "ERROR: $idfile exists but is not a readable file" >&2
  exit 2
fi

patterns="$(mktemp)" || exit 2
trap 'rm -f "$patterns"' EXIT
# The same shape scripts/gitleaks-identifier-rules.sh accepts: a line outside
# it would match nothing or nearly everything, so the file is refused.
n=0
while IFS= read -r line || [ -n "$line" ]; do
  n=$((n + 1))
  line="${line%%#*}"
  line="${line#"${line%%[![:space:]]*}"}"; line="${line%"${line##*[![:space:]]}"}"
  [ -n "$line" ] || continue
  if [[ ! "$line" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{1,63}$ ]]; then
    echo "ERROR: $idfile line $n is not a plain identifier; refusing the file" >&2
    exit 2
  fi
  printf '%s\n' "$line" >> "$patterns"
done < "$idfile"
if [ ! -s "$patterns" ]; then
  echo "WARN: $idfile holds no identifiers; the identifier check could not run here" >&2
  exit 0
fi

paths=()
for p in "${scope[@]}"; do
  if [ -e "$p" ]; then paths+=("$p"); else echo "WARN: $p is not present; not checked" >&2; fi
done
[ "${#paths[@]}" -gt 0 ] || { echo "ERROR: none of the checked paths exist; run from the repo root" >&2; exit 2; }

# grep exits 1 on no match and 2 on a read error; only 2 is a failure.
# -w matches whole words, as the gitleaks rule generator's \b does, so a
# name inside a longer word is not a hit.
set +e
raw="$(grep -rniIw -F -f "$patterns" -- "${paths[@]}")"
status=$?
set -e
[ "$status" -le 1 ] || { echo "ERROR: grep could not read the checked files (exit $status)" >&2; exit 2; }
hits="$(printf '%s\n' "$raw" | cut -d: -f1,2 | grep . || true)"
if [ -n "$hits" ]; then
  printf '%s\n' "$hits"
  echo "identifier-check: $(printf '%s\n' "$hits" | grep -c .) line(s) name an identifier from $idfile" >&2
  exit 1
fi
echo "identifier-check: no identifier from $idfile in the checked files"
