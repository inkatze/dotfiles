#!/usr/bin/env bash
# Runs a localhost Redis as a courtesy tenant of a Mac someone else uses.
# Usage: redis-gate.sh <redis-dir>, with redis.conf and redis.pass in it.
#
# Started by runner-start.sh with RUNNER_GATE pointing here. The server runs
# only while the owner has been away for RUNNER_IDLE_SECONDS (runner-gate.sh's
# owner_idle): when they return it is stopped with `shutdown nosave`, and it
# starts again once the Mac has been idle long enough. Load is deliberately not
# part of the rule, since the server's own load would otherwise stop it.
set -u

dir="${1:?usage: redis-gate.sh <redis-dir>}"
here="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
poll="${RUNNER_POLL_SECONDS:-10}"
conf="$dir/redis.conf"
passfile="$dir/redis.pass"
port="$(awk '$1 == "port" { print $2; exit }' "$conf" 2>/dev/null)"
port="${port:-6379}"

# Only the idle-time half of the runner gate; it sets its own TERM trap, which
# the one below replaces.
export RUNNER_GATE_SOURCE_ONLY=1
# shellcheck disable=SC1090,SC1091
. "${RUNNER_GATE_LIB:-$here/runner-gate.sh}" "$dir" || exit 1
unset RUNNER_GATE_SOURCE_ONLY

# The password reaches redis-cli through its environment, never its arguments,
# which any account can read in the process list.
cli() { REDISCLI_AUTH="$(cat "$passfile" 2>/dev/null)" redis-cli -h 127.0.0.1 -p "$port" "$@"; }

server_up() { [ "$(cli ping 2>/dev/null)" = PONG ]; }

server=""
stop_server() {
    local asked=""
    if server_up; then
        cli shutdown nosave >/dev/null 2>&1
        asked=1
    fi
    if [ -n "$server" ]; then
        # A server that ignored the command, or was still starting and could
        # not be asked, is told to stop; with no save points, SIGTERM writes
        # nothing either.
        if kill -0 "$server" 2>/dev/null; then
            [ -n "$asked" ] && wait_gone "$server" || kill "$server" 2>/dev/null
        fi
        wait "$server" 2>/dev/null
        server=""
    fi
}

wait_gone() {
    local i=0
    while kill -0 "$1" 2>/dev/null && [ "$i" -lt 50 ]; do
        sleep 0.1
        i=$((i + 1))
    done
    ! kill -0 "$1" 2>/dev/null
}

trap 'stop_server; exit 0' TERM INT

cd "$dir" || exit 1
while :; do
    if [ -n "$server" ] && ! kill -0 "$server" 2>/dev/null; then
        wait "$server" 2>/dev/null
        server=""
    fi
    if owner_idle; then
        if [ -z "$server" ] && ! server_up; then
            redis-server "$conf" &
            server=$!
        fi
    elif [ -n "$server" ] || server_up; then
        stop_server
    fi
    sleep "$poll" &
    wait $!
done
