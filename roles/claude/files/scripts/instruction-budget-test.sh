#!/usr/bin/env bash
# Fixture tests for instruction-budget.sh. Each case copies the tracked
# surfaces into a temp tree, plants one change, and asserts the checker's exit
# status and message. The root-file cases instead check the repo-root CLAUDE.md
# itself: its line ceiling and that its links and repo paths resolve. The
# wiring cases read lefthook.yml and the workflow, since a guard nothing runs
# fails silently.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
[ -f "$ROOT/lefthook.yml" ] || {
  echo "instruction-budget-test: must run from the dotfiles checkout (ROOT resolved to $ROOT)"
  exit 1
}
SCRIPT=roles/claude/files/scripts/instruction-budget.sh
failures=0
tmp=""
rtree=""

setup() {
  tmp="$(mktemp -d -t instruction-budget-test.XXXXXX)"
  mkdir -p "$tmp/roles/claude/files/scripts"
  cp -R "$ROOT/roles/claude/files/skills" "$tmp/roles/claude/files/"
  cp "$ROOT/roles/claude/files/CLAUDE.md" "$tmp/roles/claude/files/"
  cp "$ROOT/CLAUDE.md" "$tmp/"
  cp "$ROOT/$SCRIPT" "$tmp/$SCRIPT"
}

teardown() { rm -rf "$tmp" || true; tmp=""; }
trap 'rm -rf "${tmp:-}" "${rtree:-}"' EXIT

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

# The root file's own limits: the line ceiling the claude-context bundle sets,
# read from that bundle rather than copied, and every relative markdown link
# (inline, titled or reference-style) and backticked repo path in the file
# resolving. A repo path is a backticked span whose first segment is a
# top-level directory of the tree or of HEAD, so a renamed directory still
# flags the paths under it; placeholders, globs, `path:line` spans and
# home-relative paths are not paths. Link anchors are not checked.
top_dirs="$(git -C "$ROOT" ls-tree -d --name-only HEAD 2>/dev/null || true)"

ceiling_of() {
  sed -n 's/.*shall target [0-9][0-9]* lines and shall not exceed \([0-9][0-9]*\) lines.*/\1/p' \
    "$1" 2>/dev/null | head -n 1 || true
}

root_links() {
  perl -ne 'while (/\]\(<?([^)\s>]+)>?(?:\s+"[^"]*")?\)/g) { print "$1\n" }
    print "$1\n" if /^\s*\[[^\]]+\]:\s*<?([^\s>]+)/' "$1" 2>/dev/null |
    perl -ne 'chomp; next if m{^[a-z][a-z0-9+.-]*:}i || m{^//} || m{^#}; s/#.*//; print "$_\n"' |
    sort -u
}

root_paths() {
  perl -ne 'while (/`([^`\s]+\/[^`\s]*)`/g) { my $p = $1; next if $p =~ m{[<>*{}\$~:]} || $p =~ m{^/}; $p =~ s{/$}{}; print "$p\n" }' \
    "$1" 2>/dev/null | sort -u
}

# root_file_problems <tree> <CLAUDE.md> <claude-context requirements.md>
root_file_problems() {
  local tree="$1" claude="$2" req="$3" ceiling lines target
  ceiling="$(ceiling_of "$req")"
  if [ -z "$ceiling" ]; then
    echo "no line ceiling found in specs/claude-context/requirements.md"
  elif [ ! -f "$claude" ]; then
    echo "CLAUDE.md is missing"
  else
    lines="$(awk 'END { print NR }' "$claude")"
    [ "$lines" -le "$ceiling" ] || echo "CLAUDE.md has $lines lines, over the ceiling of $ceiling"
  fi
  while IFS= read -r target; do
    case "/$target/" in */../*)
      echo "CLAUDE.md links to $target, outside the repository"
      continue
      ;;
    esac
    [ -e "$tree/$target" ] || echo "CLAUDE.md links to $target, which does not exist"
  done < <(root_links "$claude")
  while IFS= read -r target; do
    case "/$target/" in */../*)
      echo "CLAUDE.md names $target, outside the repository"
      continue
      ;;
    esac
    [ -d "$tree/${target%%/*}" ] || grep -qxF -- "${target%%/*}" <<<"$top_dirs" || continue
    [ -e "$tree/$target" ] || echo "CLAUDE.md names $target, which does not exist"
  done < <(root_paths "$claude")
}

# One copy of the tracked and new-but-unignored files, so a gitignored local
# directory can never make a path resolve. Fixtures edit copies of the two
# files under test, and move a target aside and back rather than recopying.
rtree="$(mktemp -d -t instruction-budget-root.XXXXXX)"
(cd "$ROOT" && git ls-files -z --cached --others --exclude-standard |
  while IFS= read -r -d '' f; do if [ -e "$f" ]; then printf '%s\0' "$f"; fi; done |
  tar --null -T - -cf -) | tar -xf - -C "$rtree"
fx_claude="$rtree/.fixture-CLAUDE.md"
fx_req="$rtree/.fixture-requirements.md"
# A source missing from the tree leaves its copy absent, so the check reports
# it rather than cp aborting the suite with no FAIL line.
reset_root_fixture() {
  rm -f "$fx_claude" "$fx_req"
  if [ -f "$rtree/CLAUDE.md" ]; then cp "$rtree/CLAUDE.md" "$fx_claude"; fi
  if [ -f "$rtree/specs/claude-context/requirements.md" ]; then
    cp "$rtree/specs/claude-context/requirements.md" "$fx_req"
  fi
}

# expect_root <name> [fragment]: no fragment means the fixture must be clean.
expect_root() {
  local out
  out="$(root_file_problems "$rtree" "$fx_claude" "$fx_req")"
  if [ -z "${2:-}" ]; then
    [ -z "$out" ] || fail "$1" "$out"
  else
    [[ "$out" == *"$2"* ]] || fail "$1" "no '$2' reported: ${out:-nothing}"
  fi
}

# expect_root_moved <name> <path> <fragment>: with <path> moved aside, the
# fixture must report the fragment.
expect_root_moved() {
  if [ -z "$2" ] || [ ! -e "$rtree/$2" ]; then
    fail "$1" "no existing target '$2' to move aside"
    return
  fi
  mv "$rtree/$2" "$rtree/.fixture-moved"
  expect_root "$1" "$3"
  mv "$rtree/.fixture-moved" "$rtree/$2"
}

reset_root_fixture
expect_root root-file

ceiling="$(ceiling_of "$fx_req")"
if [ -z "$ceiling" ]; then
  fail root-ceiling "no line ceiling found in specs/claude-context/requirements.md"
else
  lines="$(awk 'END { print NR }' "$fx_claude" 2>/dev/null || true)"
  for ((i = lines; i < ceiling; i++)); do echo >>"$fx_claude"; done
  expect_root root-at-ceiling
  echo >>"$fx_claude"
  expect_root root-over-ceiling "over the ceiling of $ceiling"
  reset_root_fixture
  for ((i = lines; i < ceiling; i++)); do echo >>"$fx_claude"; done
  printf 'no final newline' >>"$fx_claude"
  expect_root root-over-ceiling-unterminated "over the ceiling of $ceiling"
fi

reset_root_fixture
perl -pi -e 's/shall not exceed \d+ lines/shall stay short/' "$fx_req"
expect_root root-ceiling-unreadable "no line ceiling found"

# A ceiling one under the file's length must trip, so the value is read from
# the bundle rather than assumed.
reset_root_fixture
below=$(($(awk 'END { print NR }' "$fx_claude" 2>/dev/null || echo 1) - 1))
perl -pi -e "s/shall not exceed \\d+ lines/shall not exceed $below lines/" "$fx_req"
expect_root root-ceiling-read "over the ceiling of $below"

reset_root_fixture
rm -f "$fx_claude"
expect_root root-file-missing "CLAUDE.md is missing"

reset_root_fixture
link="$(root_links "$fx_claude" | grep -v '\.\.' |
  while IFS= read -r l; do if [ -f "$rtree/$l" ]; then echo "$l"; break; fi; done || true)"
expect_root_moved root-link-missing "$link" "links to $link, which does not exist"

reset_root_fixture
path="$(root_paths "$fx_claude" | grep '^scripts/' | head -n 1 || true)"
expect_root_moved root-path-missing "$path" "names $path, which does not exist"
expect_root_moved root-top-dir-missing scripts "names $path, which does not exist"

# The planted fixtures below replace the file, so its own size and links
# cannot mask or trip them.
reset_root_fixture
printf '[a](docs/no-such-note.md "title")\n' >"$fx_claude"
expect_root root-link-titled "links to docs/no-such-note.md"

reset_root_fixture
printf '[r]: docs/no-such-ref.md\n' >"$fx_claude"
expect_root root-link-reference "links to docs/no-such-ref.md"

reset_root_fixture
printf '[up](../outside.md)\n' >"$fx_claude"
expect_root root-link-escapes "links to ../outside.md, outside the repository"

reset_root_fixture
printf '[web](HTTPS://example.invalid/x)\n' >"$fx_claude"
expect_root root-link-url

reset_root_fixture
printf '[a](CLAUDE.md#a-section)\n' >"$fx_claude"
expect_root root-link-anchor

reset_root_fixture
printf '%s\n' "\`../outside/x.md\`" >"$fx_claude"
expect_root root-path-escapes "names ../outside/x.md, outside the repository"

# A top-level directory not yet in HEAD still has its paths checked.
reset_root_fixture
mkdir "$rtree/fixture-top"
printf '%s\n' "\`fixture-top/missing.md\`" >"$fx_claude"
expect_root root-path-new-top-dir "names fixture-top/missing.md, which does not exist"
rmdir "$rtree/fixture-top"

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
