#!/usr/bin/env bash
# Runs redis-gate.sh against stub `redis-server`, `redis-cli` and `ioreg` in a
# scratch directory: the server starts only while the Mac is idle, is stopped
# with `shutdown nosave` using the password from the environment (never the
# arguments) when the owner returns, and starts again afterwards. Load never
# stops it. Then checks the rendered redis.conf template's required lines.
set -eu

repo="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
gate="$repo/roles/osx/files/redis/redis-gate.sh"
scratch="$(mktemp -d)"
gate_pid=""
cleanup() {
    [ -n "$gate_pid" ] && kill "$gate_pid" 2>/dev/null || true
    pkill -f "$scratch/stubs/redis-server" 2>/dev/null || true
    rm -rf "$scratch"
}
trap cleanup EXIT

stubs="$scratch/stubs" work="$scratch/redis"
mkdir -p "$stubs" "$work"
printf '%s\n' 'bind 127.0.0.1 -::1' 'port 6399' >"$work/redis.conf"
printf '%s' 's3cret-value' >"$work/redis.pass"

cat >"$stubs/redis-server" <<'STUB'
#!/bin/sh
echo "start $1" >>"$STUB_LOG"
touch "$STUB_STATE"
trap 'rm -f "$STUB_STATE"; exit 0' TERM
while [ -f "$STUB_STATE" ]; do sleep 0.1 & wait $!; done
STUB
cat >"$stubs/redis-cli" <<'STUB'
#!/bin/sh
echo "cli $* AUTH=${REDISCLI_AUTH-}" >>"$STUB_LOG"
case " $* " in
    *" ping "*) [ -f "$STUB_STATE" ] && echo PONG ;;
    *" shutdown nosave "*) rm -f "$STUB_STATE" ;;
esac
exit 0
STUB
cat >"$stubs/ioreg" <<'STUB'
#!/bin/sh
echo "    | |   \"HIDIdleTime\" = $(( $(cat "$STUB_IDLE_FILE") * 1000000000 ))"
STUB
cat >"$stubs/sysctl" <<'STUB'
#!/bin/sh
echo "{ 40.00 40.00 40.00 }"
STUB
chmod +x "$stubs"/*

export STUB_LOG="$scratch/log" STUB_STATE="$scratch/up" STUB_IDLE_FILE="$scratch/idle"
export RUNNER_GATE_LIB="$repo/roles/osx/files/runner/runner-gate.sh"
export PATH="$stubs:$PATH" RUNNER_IDLE_SECONDS=300 RUNNER_POLL_SECONDS=0.2
: >"$STUB_LOG"
echo 1000 >"$STUB_IDLE_FILE"

passed=0 failed=0
check() {
    local label="$1"
    shift
    if "$@"; then
        passed=$((passed + 1)); echo "  ok: $label"
    else
        failed=$((failed + 1)); echo "  FAIL: $label"
    fi
}
count() { grep -c "$1" "$STUB_LOG" || true; }
count_is() { [ "$(count "$1")" = "$2" ]; }
until_true() { local i=0; while ! "$@" && [ $i -lt 80 ]; do sleep 0.1; i=$((i + 1)); done; "$@"; }
is_up() { [ -f "$STUB_STATE" ]; }
is_down() { [ ! -f "$STUB_STATE" ]; }

"$gate" "$work" &
gate_pid=$!

check "idle Mac: the server starts" until_true is_up
check "it starts from the rendered config" grep -q "start $work/redis.conf" "$STUB_LOG"
sleep 0.6
check "it starts once, not on every poll" count_is "^start" 1

# Load is high throughout (the sysctl stub): it must not matter.
check "load never stops it" is_up

echo 5 >"$STUB_IDLE_FILE"
check "owner returns: the server stops" until_true is_down
check "it is stopped with shutdown nosave" grep -q "shutdown nosave" "$STUB_LOG"
check "the password comes from the environment" grep -q "shutdown nosave AUTH=s3cret-value" "$STUB_LOG"
check "the password is never in an argument" bash -c '! grep -E "^cli .*s3cret-value.* AUTH=" "$1"' _ "$STUB_LOG"
sleep 0.6
check "it stays stopped while the owner is active" is_down
check "it is not started again meanwhile" count_is "^start" 1

echo 1000 >"$STUB_IDLE_FILE"
check "idle again: it starts again" until_true is_up
check "it is the second start" count_is "^start" 2

kill -TERM "$gate_pid"
wait "$gate_pid" 2>/dev/null || true
gate_pid=""
check "stopping the gate stops the server" until_true is_down

conf="$repo/roles/osx/templates/redis.conf.j2"
for line in 'bind 127.0.0.1 -::1' 'protected-mode yes' 'port {{ osx_redis_port }}' 'save ""' 'appendonly no' 'requirepass {{ osx_redis_password }}' 'dir {{ osx_redis_dir }}'; do
    check "redis.conf has: $line" grep -qxF "$line" "$conf"
done
check "redis.conf holds no literal password" bash -c '! grep -E "^requirepass [^{]" "$1"' _ "$conf"

echo "redis-gate: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
