#!/usr/bin/env bash
# Fixture suite for claude-planwright-pin-check.sh: a concrete pin must fail
# loudly, since a silent pass is exactly the failure the check exists for.
set -uo pipefail

here="$(cd -- "$(dirname "$0")" && pwd -P)"
check="$here/claude-planwright-pin-check.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=0

ok()   { printf 'ok[%s]: %s\n' "$1" "$2"; }
fail() { printf 'FAIL[%s]: %s\n' "$1" "$2"; fails=$((fails + 1)); }

pinned() { # pinned <version>... -> tracked settings naming each version
    local rules="" v
    for v in "$@"; do
        rules+="${rules:+,}\"Bash(\$HOME/.claude/plugins/cache/planwright/planwright/$v/scripts/x.sh run *)\""
    done
    printf '{"permissions":{"allow":[%s]}}\n' "$rules"
}

# 1. a concrete pin fails, naming the version
pinned 1.2.0 >"$work/s.json"
if out=$("$check" "$work/s.json" 2>&1); then
    fail pin "exited 0 on a concrete pin"
else
    case "$out" in *"pin planwright 1.2.0;"*) ok pin "refused, naming the version" ;;
                   *) fail pin "wrong message: $out" ;; esac
fi

# 2. a concrete pin beside a glob still fails
pinned '*' 1.3.0 >"$work/s.json"
if "$check" "$work/s.json" >/dev/null 2>&1; then
    fail mixed "exited 0 with a pin beside a glob"
else
    ok mixed "a glob does not hide a pin"
fi

# 3. a version glob passes
pinned '*' '*' >"$work/s.json"
if [ "$("$check" "$work/s.json")" = OK ]; then
    ok glob "version glob accepted"
else
    fail glob "expected OK for a version glob"
fi

# 4. no planwright rule at all passes
printf '{"permissions":{"allow":["Bash(ls:*)"]}}\n' >"$work/s.json"
if [ "$("$check" "$work/s.json")" = OK ]; then
    ok no-rule "nothing pinned"
else
    fail no-rule "expected OK"
fi

# 5. unreadable settings fail rather than passing
printf 'not json\n' >"$work/s.json"
if "$check" "$work/s.json" >/dev/null 2>&1; then
    fail invalid "exited 0 on invalid JSON"
else
    ok invalid "refused invalid JSON"
fi

# 6. the tracked settings this repo ships pin nothing
if out=$("$check" "$here/../roles/claude/files/settings.json" 2>&1); then
    ok tracked "tracked settings.json pins no planwright version"
else
    fail tracked "$out"
fi

if [ "$fails" -ne 0 ]; then
    printf 'claude-planwright-pin-check-test: %d assertion(s) failed\n' "$fails"
    exit 1
fi
printf 'claude-planwright-pin-check-test: all assertions hold\n'
