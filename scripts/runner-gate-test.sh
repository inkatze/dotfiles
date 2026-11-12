#!/usr/bin/env bash
# Runs runner-gate.sh's mac_is_free decision against stubbed `stat`, `ioreg` and
# `sysctl` on PATH: idle time and load decide, never the console owner.
set -eu

repo="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
gate="$repo/roles/osx/files/runner/runner-gate.sh"
stubs="$(mktemp -d)"
trap 'rm -rf "$stubs"' EXIT

cat >"$stubs/stat" <<'STUB'
#!/bin/sh
echo "${STUB_CONSOLE-otheraccount}"
STUB
cat >"$stubs/ioreg" <<'STUB'
#!/bin/sh
[ -n "${STUB_IDLE-}" ] && echo "    | |   \"HIDIdleTime\" = $((STUB_IDLE * 1000000000))"
exit 0
STUB
cat >"$stubs/sysctl" <<'STUB'
#!/bin/sh
[ -n "${STUB_LOAD-}" ] && echo "{ $STUB_LOAD 4.00 4.00 }"
exit 0
STUB
chmod +x "$stubs"/*

passed=0 failed=0
# expect <free|busy> <console owner> <idle seconds> <load> <label>
expect() {
    local want="$1" got=busy
    if (
        export PATH="$stubs:$PATH" STUB_CONSOLE="$2" STUB_IDLE="$3" STUB_LOAD="$4"
        export RUNNER_GATE_SOURCE_ONLY=1
        # shellcheck disable=SC1090
        . "$gate" /nonexistent
        mac_is_free
    ); then got=free; fi
    if [ "$got" = "$want" ]; then
        passed=$((passed + 1)); echo "  ok: $5"
    else
        failed=$((failed + 1)); echo "  FAIL: $5 (wanted $want, got $got)"
    fi
}

expect free otheraccount 992 3.83 "another account at the console, idle, lightly loaded"
expect free "$(id -un)" 992 3.83 "own account at the console, idle, lightly loaded"
expect free root 992 3.83 "root at the console, idle, lightly loaded"
expect free '' 992 3.83 "nobody at the console, idle, lightly loaded"
expect free otheraccount 300 5.99 "idle exactly at the threshold, load just under the cap"
expect busy otheraccount 992 6.00 "idle but load at the cap"
expect busy otheraccount 992 11.2 "idle but heavily loaded"
expect busy otheraccount 5 3.83 "another account at the console, active, lightly loaded"
expect busy '' 5 3.83 "nobody at the console, active"
expect busy otheraccount 299 3.83 "one second under the idle threshold"
expect busy otheraccount '' 3.83 "idle unreadable"
expect busy otheraccount 992 '' "load unreadable"

echo "runner-gate: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
