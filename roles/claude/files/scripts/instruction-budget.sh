#!/usr/bin/env bash
# Word-budget guard for the always-loaded and on-demand instruction surfaces.
# Instruction-following degrades with load, so each surface carries a warn and
# an error threshold and growth past them has to be a visible, deliberate edit.
#
# Usage: instruction-budget.sh           check the tree rooted at the cwd
#        instruction-budget.sh --count F print F's word count
#
# Runs from the repo root (lefthook pre-commit, and CI in the skill-contracts
# job); instruction-budget-test.sh plants drifts to prove each check fires.
set -euo pipefail

# Paths the guard covers. Every file these match must have a row in SURFACES.
COVERED=(
  roles/claude/files/CLAUDE.md
  CLAUDE.md
  "roles/claude/files/skills/*/*.md"
)

# Thresholds are set by rule, never by taste. For a surface's declared word
# count n (its count at the commit that set the row):
#   warn  = 250 * ceil(n / 250) + 250
#   error = warn + 500
# A change that grows or adds a surface re-derives its row in the same commit;
# `--count <file>` gives n.
#
# path                                                     n      warn   error
SURFACES="
roles/claude/files/CLAUDE.md                               1690   2000   2500
CLAUDE.md                                                  1557   2000   2500
roles/claude/files/skills/bot-review/SKILL.md              4122   4500   5000
roles/claude/files/skills/code-review/SKILL.md             4050   4500   5000
roles/claude/files/skills/copilot-review/SKILL.md          4985   5250   5750
roles/claude/files/skills/panel-review/reviewer-backend.md 5863   6250   6750
roles/claude/files/skills/panel-review/SKILL.md            2605   3000   3500
roles/claude/files/skills/peer-review/SKILL.md             778    1250   1750
roles/claude/files/skills/review-shared/backends.md        1903   2250   2750
roles/claude/files/skills/review-shared/doctrine.md        434    750    1250
roles/claude/files/skills/review-shared/egress.md          615    1000   1500
roles/claude/files/skills/review-shared/github.md          1620   2000   2500
roles/claude/files/skills/review-shared/limits.md          117    500    1000
roles/claude/files/skills/review-shared/slack.md           730    1000   1500
roles/claude/files/skills/review-shared/workflow.md        378    750    1250
"

# Whitespace-separated words, byte-wise in the C locale. Not `wc -w`: GNU and
# BSD disagree on whether a run of non-printable bytes (a UTF-8 dash, in the C
# locale) is a word. Exits with tr's status, so a failed read is never zero.
count_words() {
  LC_ALL=C tr -s ' \t\n\r\v\f' '[\n*]' <"$1" | LC_ALL=C grep -c .
  return "${PIPESTATUS[0]}"
}

case "$#:${1:-}" in
  0:) ;;
  2:--count)
    count="$(count_words "$2")" || { echo "ERROR: cannot read $2" >&2; exit 1; }
    echo "$count"
    exit 0
    ;;
  *)
    echo "usage: instruction-budget.sh [--count <file>]" >&2
    exit 2
    ;;
esac

errors=0
warnings=0

# GitHub workflow-command escaping: data needs % CR LF; a property also : and ,.
esc_data() {
  local s="${1//%/%25}"
  s="${s//$'\r'/%0D}"
  printf '%s' "${s//$'\n'/%0A}"
}
esc_prop() {
  local s
  s="$(esc_data "$1")"
  s="${s//:/%3A}"
  printf '%s' "${s//,/%2C}"
}

err() {
  errors=$((errors + 1))
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    echo "::error file=$(esc_prop "$1")::$(esc_data "$2")"
  else
    echo "ERROR: $1: $2"
  fi
}

warn() {
  warnings=$((warnings + 1))
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    echo "::warning file=$(esc_prop "$1")::$(esc_data "$2")"
  else
    echo "WARN: $1: $2" >&2
  fi
}

declared=" "
while read -r path n w e; do
  [ -n "$path" ] || continue
  declared="$declared$path "
  if ! [[ "$n" =~ ^[0-9]+$ && "$w" =~ ^[0-9]+$ && "$e" =~ ^[0-9]+$ ]]; then
    err "$path" "malformed row '$n $w $e' (want: path n warn error, all whole numbers)"
    continue
  fi
  expected_w=$(((10#$n + 249) / 250 * 250 + 250))
  expected_e=$((expected_w + 500))
  if [ "$w" != "$expected_w" ] || [ "$e" != "$expected_e" ]; then
    err "$path" "thresholds $w/$e do not match the rule for declared count $n (expected $expected_w/$expected_e)"
  fi
  if ! count="$(count_words "$path" 2>/dev/null)"; then
    err "$path" "surface is declared but cannot be read"
    continue
  fi
  if [ "$count" -gt "$e" ]; then
    err "$path" "$count words exceeds the error threshold $e"
  elif [ "$count" -gt "$w" ]; then
    warn "$path" "$count words exceeds the warn threshold $w (error at $e)"
  fi
done <<<"$SURFACES"

for pattern in "${COVERED[@]}"; do
  # Unquoted on purpose: the glob is the pattern.
  # shellcheck disable=SC2206
  matches=($pattern)
  for path in "${matches[@]}"; do
    # A dangling symlink fails -e but is still a covered surface.
    [ -e "$path" ] || [ -L "$path" ] || continue
    case "$declared" in
      *" $path "*) ;;
      *) err "$path" "covered surface has no declared thresholds (add a SURFACES row; n from --count)" ;;
    esac
  done
done

if [ "$errors" -gt 0 ]; then
  echo "instruction-budget: $errors error(s), $warnings warning(s)"
  exit 1
fi
echo "instruction-budget: all surfaces within budget ($warnings warning(s))"
