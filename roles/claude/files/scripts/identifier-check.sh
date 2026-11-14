#!/usr/bin/env bash
# Review-time check that no live instruction file names an external project,
# employer organization or work repository. The names come from the untracked
# machine-local identifier file (the one scripts/gitleaks-identifier-rules.sh
# reads), so this public repo never carries the names it checks for.
#
# Usage: identifier-check.sh [<file>...]
# With no arguments it scans the fixed scope below, from the repo root. With
# file arguments it scans exactly those files instead, from anywhere: this is
# the form that gates publishing a PR body (identifier-check.sh <body file>).
#
# Reports file and line only, never the matched name. A missing identifier
# file is a warning, not a pass. Run by hand at task review and from
# skill-contracts-test.sh; it is never a commit gate.
# Exit 1 means hits; exit 2 means the check could not run as asked: an
# unreadable identifier file, a named file that is not readable or whose path
# holds a newline, or, with named files, an absent or empty identifier file.
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

# With named files a body gate must never pass unscanned, so the missing or
# empty identifier file is an error there; the no-argument review report only
# warns.
if [ ! -e "$idfile" ]; then
  if [ "$#" -gt 0 ]; then echo "ERROR: no identifier file at $idfile; the named files were not scanned" >&2; exit 2; fi
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
  if [ "$#" -gt 0 ]; then echo "ERROR: $idfile holds no identifiers; the named files were not scanned" >&2; exit 2; fi
  echo "WARN: $idfile holds no identifiers; the identifier check could not run here" >&2
  exit 0
fi

# A named path is user-chosen and may itself hold an identifier, so every
# message that shows one goes through here; a grep error counts as a match.
shown() {
  local rc=0
  printf '%s\n' "$1" | grep -qiF -f "$patterns" || rc=$?
  if [ "$rc" -eq 1 ]; then printf '%s' "$1"; else printf 'argument %s' "$2"; fi
}

paths=()
if [ "$#" -gt 0 ]; then
  i=0
  for p in "$@"; do
    i=$((i + 1))
    case "$p" in *$'\n'*) echo "ERROR: a named path contains a newline" >&2; exit 2 ;; esac
    if [ ! -f "$p" ] || [ ! -r "$p" ]; then echo "ERROR: $(shown "$p" "$i") is not a readable file" >&2; exit 2; fi
    paths+=("$p")
  done
else
  for p in "${scope[@]}"; do
    if [ -e "$p" ]; then paths+=("$p"); else echo "WARN: $p is not present; not checked" >&2; fi
  done
  [ "${#paths[@]}" -gt 0 ] || { echo "ERROR: none of the checked paths exist; run from the repo root" >&2; exit 2; }
fi

# grep exits 1 on no match and 2 on a read error; only 2 is a failure.
# -w matches whole words, as the gitleaks rule generator's \b does, so a
# name inside a longer word is not a hit.
if [ "$#" -gt 0 ]; then
  # Named files are scanned one by one as text (-a): -I would skip a binary or
  # invalid-encoding body and report it clean. The report is built in bash so
  # a path is never interpreted, and one that itself holds an identifier is
  # shown by position, never echoed. Only line numbers leave the pipe, so a NUL
  # byte in the body cannot reach the command substitution.
  hits=""
  i=0
  for p in "${paths[@]}"; do
    i=$((i + 1))
    set +e
    lines="$(grep -naiw -F -f "$patterns" -- "$p" | cut -d: -f1)"
    status=$?
    set -e
    [ "$status" -le 1 ] || { echo "ERROR: grep could not read $(shown "$p" "$i") (exit $status)" >&2; exit 2; }
    [ -n "$lines" ] || continue
    label="$(shown "$p" "$i")"
    while read -r ln; do hits+="$label:$ln"$'\n'; done <<< "$lines"
  done
  hits="$(printf '%s' "$hits" | grep . || true)"
else
  set +e
  raw="$(grep -rHniIw -F -f "$patterns" -- "${paths[@]}")"
  status=$?
  set -e
  [ "$status" -le 1 ] || { echo "ERROR: grep could not read the checked files (exit $status)" >&2; exit 2; }
  hits="$(printf '%s\n' "$raw" | cut -d: -f1,2 | grep . || true)"
fi
if [ -n "$hits" ]; then
  printf '%s\n' "$hits"
  echo "identifier-check: $(printf '%s\n' "$hits" | grep -c .) line(s) name an identifier from $idfile" >&2
  exit 1
fi
echo "identifier-check: no identifier from $idfile in the checked files"
