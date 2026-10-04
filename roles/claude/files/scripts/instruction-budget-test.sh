#!/usr/bin/env bash
# Fixture tests for instruction-budget.sh. Each case copies the tracked
# surfaces into a temp tree, plants one change, and asserts the checker's exit
# status and message. The wiring cases read lefthook.yml and the workflow,
# since a guard nothing runs fails silently.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
[ -f "$ROOT/lefthook.yml" ] || {
  echo "instruction-budget-test: must run from the dotfiles checkout (ROOT resolved to $ROOT)"
  exit 1
}
SCRIPT=roles/claude/files/scripts/instruction-budget.sh
failures=0
tmp=""

setup() {
  tmp="$(mktemp -d -t instruction-budget-test.XXXXXX)"
  mkdir -p "$tmp/roles/claude/files/scripts"
  cp -R "$ROOT/roles/claude/files/skills" "$tmp/roles/claude/files/"
  cp "$ROOT/roles/claude/files/CLAUDE.md" "$tmp/roles/claude/files/"
  cp "$ROOT/CLAUDE.md" "$tmp/"
  cp "$ROOT/$SCRIPT" "$tmp/$SCRIPT"
}

teardown() { rm -rf "$tmp" || true; tmp=""; }
trap '[ -n "$tmp" ] && rm -rf "$tmp"' EXIT

fail() { echo "FAIL $1: $2"; failures=$((failures + 1)); }

# append_words <file> <n>
append_words() {
  local i
  for ((i = 0; i < $2; i++)); do printf 'word '; done >>"$tmp/$1"
}

# set_row <path> <n> <warn> <error>: replace a SURFACES row in the temp script.
set_row() {
  perl -pi -e "s{^\Q$1\E\s.*\$}{$1 $2 $3 $4}" "$tmp/$SCRIPT"
}

# check <name> <expected exit> <stdout+stderr fragment or ""> <forbidden fragment or ""> [checker args]
check() {
  local name="$1" want="$2" fragment="$3" forbidden="$4" out rc=0
  shift 4
  # CI sets GITHUB_ACTIONS, which switches the checker to annotation output.
  out="$(cd "$tmp" && env -u GITHUB_ACTIONS bash "$SCRIPT" "$@" 2>&1)" || rc=$?
  if [ "$rc" != "$want" ]; then
    fail "$name" "exit $rc, want $want: $out"
  elif [ -n "$fragment" ] && [[ "$out" != *"$fragment"* ]]; then
    fail "$name" "output lacks '$fragment': $out"
  elif [ -n "$forbidden" ] && [[ "$out" == *"$forbidden"* ]]; then
    fail "$name" "output has '$forbidden': $out"
  fi
  teardown
}

peer=roles/claude/files/skills/peer-review/SKILL.md

setup
check baseline 0 "all surfaces within budget" "WARN"

setup
read -r _ n w e < <(grep "^$peer " "$tmp/$SCRIPT")
append_words "$peer" $((e + 1 - n))
check overage 1 "exceeds the error threshold" ""

setup
append_words "$peer" $((w + 1 - n))
check warn-range 0 "exceeds the warn threshold" "ERROR"

setup
append_words "$peer" 1
check under-warn 0 "all surfaces within budget" "WARN"

setup
rm "$tmp/$peer"
check unreadable 1 "cannot be read" ""

setup
rm "$tmp/roles/claude/files/CLAUDE.md"
check unreadable-global 1 "cannot be read" ""

setup
mkdir "$tmp/roles/claude/files/skills/new-review" && printf "new skill\n" >"$tmp/roles/claude/files/skills/new-review/SKILL.md"
check no-thresholds 1 "skills/new-review/SKILL.md: covered surface has no declared thresholds" ""

setup
set_row "$peer" "$n" "$((w + 250))" "$((e + 250))"
check formula-mismatch 1 "do not match the rule" ""

setup
set_row "$peer" 2500 2750 3250
check formula-exact-multiple 0 "all surfaces within budget" ""

setup
set_row roles/claude/files/CLAUDE.md 0 250 750
check formula-zero 1 "exceeds the error threshold 750" "do not match the rule"

setup
: >"$tmp/empty.md"
got="$(cd "$tmp" && bash "$SCRIPT" --count empty.md)" || fail empty-count "exit non-zero on an empty file"
[ "$got" = 0 ] || fail empty-count "counted '$got', want 0"
teardown

setup
set_row "$peer" 2500 3000 3500
check formula-exact-multiple-off-by-one 1 "do not match the rule" ""

setup
append_words "$peer" $((w + 1 - n))
out="$(cd "$tmp" && GITHUB_ACTIONS=true bash "$SCRIPT" 2>/dev/null)" || true
[[ "$out" == *"::warning file=$peer::"* ]] || fail ci-annotation "no warning annotation on stdout: $out"
teardown

# Multibyte punctuation and a non-breaking space are not whitespace in the C
# locale: 'a', the dash, 'b<NBSP>c' and the quoted word are four words.
setup
printf 'a \xe2\x80\x94 b\xc2\xa0c\t\xe2\x80\x9cd\xe2\x80\x9d\r\n\n' >"$tmp/mb.txt"
got="$(cd "$tmp" && bash "$SCRIPT" --count mb.txt)"
[ "$got" = 4 ] || fail multibyte-count "counted $got, want 4"
teardown

# A read that fails must never count as zero words. Root reads a 000 file.
if [ "$(id -u)" != 0 ]; then
  setup
  printf 'some words\n' >"$tmp/locked.txt"
  chmod 000 "$tmp/locked.txt"
  if got="$(cd "$tmp" && bash "$SCRIPT" --count locked.txt 2>/dev/null)"; then
    fail count-unreadable "exit 0 with count '$got' on an unreadable file"
  elif [ -n "$got" ]; then
    fail count-unreadable "printed '$got' on stdout for an unreadable file"
  fi
  chmod 600 "$tmp/locked.txt"
  teardown
fi

setup
set_row "$peer" x 2750 3250
check malformed-count 1 "malformed row" ""

setup
set_row "$peer" "$n" "$w" ""
check malformed-missing-field 1 "malformed row" ""

setup
ln -s missing.md "$tmp/roles/claude/files/skills/peer-review/dangling.md"
check dangling-symlink 1 "skills/peer-review/dangling.md: covered surface has no declared thresholds" ""

setup
check bad-argument 2 "usage:" "" --bogus
setup
out="$(cd "$tmp" && bash "$SCRIPT" --count CLAUDE.md extra 2>&1)" && fail count-extra-argument "accepted: $out"
teardown

setup
printf 'x\n' >"$tmp/roles/claude/files/skills/peer-review/a,b%c.md"
out="$(cd "$tmp" && GITHUB_ACTIONS=true bash "$SCRIPT" 2>/dev/null)" || true
[[ "$out" == *"::error file=roles/claude/files/skills/peer-review/a%2Cb%25c.md::"* ]] ||
  fail ci-annotation-escaped "annotation path not escaped: $out"
teardown


lefthook_run="$(awk '/^    instruction-budget:/{f=1;next} f&&/^    [a-z]/{f=0} f' "$ROOT/lefthook.yml")"
[[ "$lefthook_run" == *"run: $SCRIPT"* ]] || fail lefthook-entry "no instruction-budget command running $SCRIPT"
[[ "$lefthook_run" == *"glob:"*"CLAUDE.md"*"skills/*/*.md"* ]] || fail lefthook-glob "entry has no glob over the surfaces"

workflow="$ROOT/.github/workflows/test.yml"
ci_job="$(awk '/^  skill-contracts:/{f=1;next} f&&/^  [a-z]/{f=0} f' "$workflow")"
[[ "$ci_job" == *"run: $SCRIPT"* ]] || fail ci-step "skill-contracts job has no step running $SCRIPT"
ci_on="$(awk '/^on:/{f=1;next} f&&/^[a-z]/{f=0} f' "$workflow" | tr -d ' \n')"
[[ "$ci_on" == *"pull_request:branches:[main]"*"push:branches:[main]"* ]] ||
  fail ci-triggers "workflow does not run on every pull request and every push to main"

if [ "$failures" -gt 0 ]; then
  echo "instruction-budget-test: $failures failure(s)"
  exit 1
fi
echo "instruction-budget-test: all cases pass"
