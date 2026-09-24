#!/usr/bin/env bash
# Fixture suite for roles/claude/files/scripts/statusline.sh. Claude Code
# leaves fields out or sends null early in a session (context_window before
# the first API call, for one), so every segment has to vanish cleanly
# instead of rendering "null" or failing the whole line.
set -uo pipefail

# Under a git hook (lefthook) GIT_DIR and GIT_INDEX_FILE point at the outer
# repo, and the fixture repo's commit below would land there instead.
# shellcheck disable=SC2046
unset $(git rev-parse --local-env-vars)
# Fail closed: with those still set, the fixtures below would write into a
# repository this suite does not own.
if [ -n "${GIT_DIR:-}${GIT_INDEX_FILE:-}${GIT_WORK_TREE:-}" ]; then
    printf 'claude-statusline-test: git environment still set; refusing to run fixtures\n' >&2
    exit 2
fi

here="$(cd -- "$(dirname "$0")" && pwd -P)"
statusline="$here/../roles/claude/files/scripts/statusline.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=0

ok()   { printf 'ok[%s]: %s\n' "$1" "$2"; }
fail() { printf 'FAIL[%s]: %s\n' "$1" "$2"; fails=$((fails + 1)); }

# check <name> <expected> <json>
# An env prefix on the call (`GIT_DIR=... check ...`) reaches the script.
# The exit status rides along after the output so that $(...) cannot eat a
# missing or surplus newline: a non-empty line must be exactly one row.
check() {
    local got rc want
    got=$(printf '%s' "$3" | "$statusline" 2>"$work/stderr"; printf '\nrc=%s' "$?")
    rc=${got##*rc=}
    got=${got%$'\n'rc=*}
    want="${2:+$2$'\n'}"
    if [ "$rc" -ne 0 ]; then
        fail "$1" "exited $rc: $(cat "$work/stderr")"
    elif [ -s "$work/stderr" ]; then
        fail "$1" "wrote to stderr: $(cat "$work/stderr")"
    elif [ "$got" != "$want" ]; then
        # %q, so a regression cannot write its escape bytes to the terminal.
        fail "$1" "expected $(printf '%q' "$want"), got $(printf '%q' "$got")"
    else
        ok "$1" "'$2'"
    fi
}

repo="$work/myrepo"
git init -q -b feat/x "$repo"
plain="$work/plain dir"
mkdir -p "$plain"

check full "myrepo  feat/x · Opus 5.5 · ctx 42%" \
    "{\"workspace\":{\"current_dir\":\"$repo\"},\"model\":{\"display_name\":\"Opus 5.5\"},\"context_window\":{\"used_percentage\":42,\"remaining_percentage\":58}}"

other="$work/other"
git init -q -b other-branch "$other"
GIT_DIR="$other/.git" check ignores-inherited-git-dir "myrepo  feat/x" \
    "{\"workspace\":{\"current_dir\":\"$repo\"}}"
GIT_OBJECT_DIRECTORY=/nonexistent check ignores-inherited-object-dir "myrepo  feat/x" \
    "{\"workspace\":{\"current_dir\":\"$repo\"}}"

check fractional-floors "myrepo  feat/x · Opus 5.5 · ctx 23%" \
    "{\"workspace\":{\"current_dir\":\"$repo\"},\"model\":{\"display_name\":\"Opus 5.5\"},\"context_window\":{\"used_percentage\":23.9}}"

check no-context-window "myrepo  feat/x · Opus 5.5" \
    "{\"workspace\":{\"current_dir\":\"$repo\"},\"model\":{\"display_name\":\"Opus 5.5\"}}"

check null-percentage "myrepo  feat/x · Opus 5.5" \
    "{\"workspace\":{\"current_dir\":\"$repo\"},\"model\":{\"display_name\":\"Opus 5.5\"},\"context_window\":{\"used_percentage\":null}}"

check no-model "myrepo  feat/x · ctx 7%" \
    "{\"workspace\":{\"current_dir\":\"$repo\"},\"context_window\":{\"used_percentage\":7}}"

check string-percentage "myrepo  feat/x · Opus 5.5" \
    "{\"workspace\":{\"current_dir\":\"$repo\"},\"model\":{\"display_name\":\"Opus 5.5\"},\"context_window\":{\"used_percentage\":\"42\"}}"

check non-git-dir "plain dir · Opus 5.5 · ctx 0%" \
    "{\"workspace\":{\"current_dir\":\"$plain\"},\"model\":{\"display_name\":\"Opus 5.5\"},\"context_window\":{\"used_percentage\":0}}"

check cwd-fallback "plain dir · Opus 5.5" \
    "{\"cwd\":\"$plain\",\"model\":{\"display_name\":\"Opus 5.5\"}}"

check trailing-slash "plain dir · Opus 5.5" \
    "{\"workspace\":{\"current_dir\":\"$plain/\"},\"model\":{\"display_name\":\"Opus 5.5\"}}"

check root-dir "/ · Opus 5.5" \
    '{"workspace":{"current_dir":"/"},"model":{"display_name":"Opus 5.5"}}'

check missing-dir "gone · Opus 5.5 · ctx 42%" \
    "{\"workspace\":{\"current_dir\":\"$work/gone\"},\"model\":{\"display_name\":\"Opus 5.5\"},\"context_window\":{\"used_percentage\":42}}"

check no-dir-field "Opus 5.5 · ctx 42%" \
    '{"model":{"display_name":"Opus 5.5"},"context_window":{"used_percentage":42}}'

# A directory name is attacker-choosable content (a cloned repo), and the
# line goes straight to the terminal.
check strips-control-chars "evil]0;pwnedname · Opus 5.5" \
    '{"workspace":{"current_dir":"/tmp/evil\u001b]0;pwnedname"},"model":{"display_name":"Opus 5.5"}}'
check strips-bel-del "xyz · Opus 5.5" \
    '{"workspace":{"current_dir":"/tmp/x\u0007y\u007fz"},"model":{"display_name":"Opus 5.5"}}'
check strips-model-escape "plain dir · O[2Jpus" \
    "{\"workspace\":{\"current_dir\":\"$plain\"},\"model\":{\"display_name\":\"O\\u001b[2Jpus\"}}"
# C1 controls (U+009B is a one-character CSI) and bidi overrides are not in
# the C0 range, and git refnames admit both, so the branch is a second way in.
check strips-c1-controls "a2Jb · Opus 5.5" \
    '{"workspace":{"current_dir":"/tmp/a\u009b2Jb"},"model":{"display_name":"Opus 5.5"}}'
check strips-bidi-override "plain dir · Opus 5.5" \
    "{\"workspace\":{\"current_dir\":\"$plain\"},\"model\":{\"display_name\":\"O\\u202epus 5.5\"}}"
hostile="$work/hostile"
git init -q -b $'evil\xc2\x9b2J' "$hostile"
check strips-branch-controls "hostile  evil2J · Opus 5.5" \
    "{\"workspace\":{\"current_dir\":\"$hostile\"},\"model\":{\"display_name\":\"Opus 5.5\"}}"

# The branch must come from the directory Claude Code named, not from the
# neighbour its sanitized name happens to spell.
newline_dir="$work/x"$'\n'"y"
mkdir -p "$newline_dir"
git init -q -b wrong-neighbour "$work/xy"
check newline-dir-keeps-real-path "xy · Opus 5.5" \
    "{\"workspace\":{\"current_dir\":\"$work/x\\ny\"},\"model\":{\"display_name\":\"Opus 5.5\"}}"

git -C "$repo" -c user.name=t -c user.email=t@t -c commit.gpgsign=false \
    commit -q --allow-empty --no-verify -m init
git -C "$repo" checkout -q --detach
check detached-head "myrepo · Opus 5.5" \
    "{\"workspace\":{\"current_dir\":\"$repo\"},\"model\":{\"display_name\":\"Opus 5.5\"}}"

check empty-object "" '{}'
check invalid-json "" 'not json'
check empty-input "" ''

# The wiring, since a renamed script or a dropped key leaves the status line
# silently blank rather than failing anywhere.
settings="$here/../roles/claude/files/settings.json"
wired=$(jq -r '.statusLine | "\(.type) \(.command)"' "$settings")
# shellcheck disable=SC2016 # the literal $HOME is what Claude Code's shell expands
if [ "$wired" = 'command $HOME/.claude/scripts/statusline.sh' ] && [ -x "$statusline" ]; then
    ok wired "settings.json runs the executable script"
else
    fail wired "settings.json statusLine is '$wired', script executable: $([ -x "$statusline" ] && echo yes || echo no)"
fi

# The suite's own safety, since CI has no hook environment to notice its
# loss: re-run everything above with the hook's variables aimed at a
# sacrificial repository and assert nothing there moved.
if [ -z "${STATUSLINE_TEST_NESTED:-}" ]; then
    outer="$work/outer"
    git init -q -b main "$outer"
    git -C "$outer" -c user.name=t -c user.email=t@t -c commit.gpgsign=false \
        commit -q --allow-empty --no-verify -m base
    outer_state() {
        git -C "$outer" rev-parse HEAD
        git -C "$outer" symbolic-ref HEAD
        git -C "$outer" config core.bare
        git -C "$outer" rev-list --count --all
    }
    before=$(outer_state)
    if STATUSLINE_TEST_NESTED=1 GIT_DIR="$outer/.git" GIT_INDEX_FILE="$outer/.git/index" \
        GIT_WORK_TREE="$outer" "$0" >"$work/nested.log" 2>&1; then
        nested_rc=0
    else
        nested_rc=$?
    fi
    after=$(outer_state)
    if [ "$nested_rc" -ne 0 ]; then
        fail hook-env-isolated "nested run exited $nested_rc: $(tail -n 3 "$work/nested.log")"
    elif [ "$before" != "$after" ]; then
        fail hook-env-isolated "outer repo changed under a hook environment: $(printf '%s' "$after" | tr '\n' ' ')"
    else
        ok hook-env-isolated "fixtures stayed out of the repo the hook variables named"
    fi
fi

if [ "$fails" -ne 0 ]; then
    printf 'claude-statusline-test: %d assertion(s) failed\n' "$fails"
    exit 1
fi
printf 'claude-statusline-test: all assertions hold\n'
