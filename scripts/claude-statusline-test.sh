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

here="$(cd -- "$(dirname "$0")" && pwd -P)"
statusline="$here/../roles/claude/files/scripts/statusline.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=0

ok()   { printf 'ok[%s]: %s\n' "$1" "$2"; }
fail() { printf 'FAIL[%s]: %s\n' "$1" "$2"; fails=$((fails + 1)); }

# check <name> <expected> <json>
check() {
    local out rc
    out=$(printf '%s' "$3" | "$statusline" 2>"$work/stderr")
    rc=$?
    if [ "$rc" -ne 0 ]; then
        fail "$1" "exited $rc"
    elif [ -s "$work/stderr" ]; then
        fail "$1" "wrote to stderr: $(cat "$work/stderr")"
    elif [ "$out" != "$2" ]; then
        fail "$1" "expected '$2', got '$out'"
    else
        ok "$1" "'$out'"
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
out=$(printf '%s' "{\"workspace\":{\"current_dir\":\"$repo\"}}" | GIT_DIR="$other/.git" "$statusline")
if [ "$out" = "myrepo  feat/x" ]; then
    ok ignores-inherited-git-dir "'$out'"
else
    fail ignores-inherited-git-dir "expected 'myrepo  feat/x', got '$out'"
fi

check fractional-floors "myrepo  feat/x · Opus 5.5 · ctx 23%" \
    "{\"workspace\":{\"current_dir\":\"$repo\"},\"model\":{\"display_name\":\"Opus 5.5\"},\"context_window\":{\"used_percentage\":23.9}}"

check no-context-window "myrepo  feat/x · Opus 5.5" \
    "{\"workspace\":{\"current_dir\":\"$repo\"},\"model\":{\"display_name\":\"Opus 5.5\"}}"

check null-percentage "myrepo  feat/x · Opus 5.5" \
    "{\"workspace\":{\"current_dir\":\"$repo\"},\"model\":{\"display_name\":\"Opus 5.5\"},\"context_window\":{\"used_percentage\":null}}"

check no-model "myrepo  feat/x · ctx 7%" \
    "{\"workspace\":{\"current_dir\":\"$repo\"},\"context_window\":{\"used_percentage\":7}}"

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

if [ "$fails" -ne 0 ]; then
    printf 'claude-statusline-test: %d assertion(s) failed\n' "$fails"
    exit 1
fi
printf 'claude-statusline-test: all assertions hold\n'
