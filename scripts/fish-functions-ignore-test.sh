#!/usr/bin/env bash
# Asserts that every file in the fish functions directory is either tracked or
# ignored, never neither.
#
# That directory is the one place under roles/fish/files/fish/ that mixes
# repo-owned functions with fisher-installed ones, so unlike conf.d,
# completions and themes it cannot be ignored wholesale. It carries a rule per
# plugin name instead (`_*` covers the private helpers; fisher.fish and
# bass.fish are named outright), and every plugin that installs a function
# without a leading underscore needs another one.
#
# Nothing reported that gap before this: the file simply appeared as untracked,
# and the next `git add -A` would commit a plugin's code into a public repo
# under a path this repo claims to own.
#
# Deliberately not solved by ignoring the directory and un-ignoring each
# repo-owned function: that inverts the failure rather than removing it, and
# the inverted one is worse. A new repo-owned function would be ignored on
# arrival, absent from `git status`, and easy to leave uncommitted -- so the
# machine would have a function nothing provisions.
#
# Coverage limit, measured: once a stray is *staged* it is indistinguishable
# from a legitimate new repo function (`ls-files --others` and `check-ignore`
# both report nothing), so a single `git add -A && git commit` that sweeps a
# fresh plugin file in escapes the hard assertion. The staged-additions note
# below is the cover for that path: it cannot fail the commit without also
# failing every genuine new function, so it prints and lets the human judge.
set -uo pipefail

here="$(cd -- "$(dirname "$0")" && pwd -P)"
repo="$(cd -- "$here/.." && pwd -P)"
dir="roles/fish/files/fish/functions"
fails=0

cd "$repo" || exit 2

if [ ! -d "$dir" ]; then
    echo "FAIL: $dir does not exist" >&2
    exit 1
fi

# --others --exclude-standard lists exactly the files git considers untracked
# and not ignored, which is the state being asserted against.
stray="$(git ls-files --others --exclude-standard -- "$dir")"

if [ -n "$stray" ]; then
    echo "FAIL[unclaimed-function]: file(s) in $dir are neither tracked nor ignored:" >&2
    printf '%s\n' "$stray" | sed 's/^/    /' >&2
    cat >&2 <<'MSG'

  A fisher plugin most likely installed a function whose name has no leading
  underscore. Add it to .gitignore beside fisher.fish and bass.fish, or commit
  it if it is genuinely this repo's.
MSG
    fails=$((fails + 1))
else
    echo "ok[unclaimed-function]: every file in the functions directory is tracked or ignored"
fi

# Empty outside a commit being prepared, so this is silent on a plain run and
# speaks only from the pre-commit hook.
if git rev-parse --verify -q HEAD >/dev/null; then
    added="$(git diff --cached --name-only --diff-filter=A -- "$dir")"
    if [ -n "$added" ]; then
        echo "note: new file(s) being committed into $dir:" >&2
        printf '%s\n' "$added" | sed 's/^/    /' >&2
        echo "  Confirm these are this repo's own functions and not a plugin's." >&2
    fi
fi

if [ "$fails" -eq 0 ]; then
    echo "fish-functions-ignore-test: all assertions hold"
else
    echo "fish-functions-ignore-test: $fails assertion(s) failed"
    exit 1
fi
