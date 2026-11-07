#!/usr/bin/env bash
# Fixture suite for claude-planwright-pin-check.sh: a stale pin must fail
# loudly, since a silent pass is exactly the failure the check exists for.
set -uo pipefail

here="$(cd -- "$(dirname "$0")" && pwd -P)"
check="$here/claude-planwright-pin-check.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=0

ok()   { printf 'ok[%s]: %s\n' "$1" "$2"; }
fail() { printf 'FAIL[%s]: %s\n' "$1" "$2"; fails=$((fails + 1)); }

pinned() { # pinned <version> -> tracked settings naming that version
    printf '{"permissions":{"allow":["Bash($HOME/.claude/plugins/cache/planwright/planwright/%s/scripts/x.sh run:*)"]}}\n' "$1"
}
installed() { # installed <version> -> plugin record holding that version
    printf '{"plugins":{"planwright@planwright":[{"scope":"user","version":"%s"}]}}\n' "$1"
}

# 1. pin matches the install
pinned 1.2.0 >"$work/s.json"; installed 1.2.0 >"$work/i.json"
if [ "$("$check" "$work/s.json" "$work/i.json")" = OK ]; then
    ok matching "pinned version installed"
else
    fail matching "expected OK"
fi

# 2. a planwright update leaves the pin stale
installed 1.3.0 >"$work/i.json"
if out=$("$check" "$work/s.json" "$work/i.json" 2>&1); then
    fail stale "exited 0 on a stale pin"
else
    case "$out" in *"pin planwright 1.2.0, installed is 1.3.0"*) ok stale "refused, naming both versions" ;;
                   *) fail stale "wrong message: $out" ;; esac
fi

# 3. no pin at all needs no plugin record
printf '{"permissions":{"allow":["Bash(ls:*)"]}}\n' >"$work/s.json"
if [ "$("$check" "$work/s.json" "$work/absent.json")" = OK ]; then
    ok no-pin "nothing pinned, nothing checked"
else
    fail no-pin "expected OK"
fi

# 3b. a version glob is not a pin, whatever is installed
pinned '*' >"$work/s.json"
if [ "$("$check" "$work/s.json" "$work/absent.json")" = OK ]; then
    ok glob "version glob never stale"
else
    fail glob "expected OK for a version glob"
fi

# 4. a pin with no plugin record fails rather than passing
pinned 1.2.0 >"$work/s.json"
if "$check" "$work/s.json" "$work/absent.json" >/dev/null 2>&1; then
    fail no-record "exited 0 without a plugin record"
else
    ok no-record "refused without a plugin record"
fi

# 5. the tracked settings this repo ships parse and yield a pin or none
if "$check" "$here/../roles/claude/files/settings.json" "$work/i.json" >/dev/null 2>&1 \
    || [ $? -eq 1 ]; then
    ok tracked-parses "tracked settings.json is readable by the check"
else
    fail tracked-parses "check could not read the tracked settings"
fi

if [ "$fails" -ne 0 ]; then
    printf 'claude-planwright-pin-check-test: %d assertion(s) failed\n' "$fails"
    exit 1
fi
printf 'claude-planwright-pin-check-test: all assertions hold\n'
