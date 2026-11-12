#!/usr/bin/env bash
# Runs one PostgreSQL data directory as a courtesy tenant of a Mac someone else
# uses. Usage: postgres-gate.sh <data-dir>
#
# The server starts only while the Mac is free (runner-gate.sh's mac_is_free:
# the keyboard and mouse still for RUNNER_IDLE_SECONDS and the one-minute load
# under RUNNER_LOAD_MAX). It listens on localhost and on a socket in
# POSTGRES_SOCKET_DIR, which only this account can enter; the cluster takes
# peer logins on the socket and scram passwords over TCP. When the owner
# returns (input within RUNNER_IDLE_SECONDS) it is stopped with a fast
# shutdown: open sessions are disconnected and their transactions rolled back,
# and committed data is flushed, never killed mid-write. Load alone never stops
# it, since a test run loads the Mac through the server it is using.
set -u

dir="${1:?usage: postgres-gate.sh <data-dir>}"
port="${POSTGRES_PORT:-5432}"
role="${POSTGRES_ROLE:-fleet}"
max_connections="${POSTGRES_MAX_CONNECTIONS:-100}"
sockdir="${POSTGRES_SOCKET_DIR:?POSTGRES_SOCKET_DIR is not set}"
pgpass="${PGPASSFILE:-$HOME/.pgpass}"
poll="${RUNNER_POLL_SECONDS:-10}"
here="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# The decision functions only; runner-gate.sh's loop stays unstarted.
# shellcheck disable=SC2034
RUNNER_GATE_SOURCE_ONLY=1
# shellcheck disable=SC1090,SC1091
. "${RUNNER_GATE_LIB:-$here/runner-gate.sh}" "$dir" || exit 1
unset RUNNER_GATE_SOURCE_ONLY

server_running() { pg_ctl -D "$dir" status >/dev/null 2>&1; }

# The role's password as the play stored it in the .pgpass, unescaped; empty
# when there is none.
pgpass_password() {
    local line
    line="$(grep -m1 "^localhost:$port:\*:$role:" "$pgpass" 2>/dev/null)" || return 0
    printf '%s\n' "${line#localhost:"$port":\*:"$role":}" | sed -e 's/\\\\/\\/g' -e 's/\\:/:/g'
}

# Over the socket, as peer, so nothing secret is needed to reach it. Checks
# before creating, so it is safe on every start. The password goes in on
# stdin, never an argument, which `ps` would show.
ensure_role() {
    local found pw
    found="$(psql -h "$sockdir" -p "$port" -d postgres -tAc \
        "select 1 from pg_roles where rolname = '$role'" 2>/dev/null)"
    [ "$found" = 1 ] || createuser -h "$sockdir" -p "$port" -s "$role" || return 1
    pw="$(pgpass_password)"
    [ -n "$pw" ] || return 0
    printf "alter role \"%s\" password '%s'\n" "$role" "${pw//\'/\'\'}" |
        psql -q -h "$sockdir" -p "$port" -d postgres -v ON_ERROR_STOP=1 -f - >/dev/null
}

start_server() {
    [ -f "$dir/PG_VERSION" ] || { echo "postgres-gate: no cluster in $dir" >&2; return 1; }
    pg_ctl -D "$dir" -l "$dir/server.log" -w \
        -o "-c listen_addresses=localhost -c port=$port -c unix_socket_directories=$sockdir -c unix_socket_permissions=0700 -c max_connections=$max_connections" start
}

stop_server() {
    role_ready=""
    pg_ctl -D "$dir" -m fast -w stop
}

# One pass of the loop. The role is checked on every pass until it succeeds
# once, so a failure right after a start is retried rather than left until the
# next restart.
role_ready=""
tick() {
    if server_running; then
        owner_idle || { stop_server; return 0; }
        [ -n "$role_ready" ] || { ensure_role && role_ready=1; }
    elif mac_is_free; then
        start_server
    fi
}

trap 'server_running && stop_server; exit 0' TERM INT

# Lets the test source the functions without starting the loop.
[ -n "${POSTGRES_GATE_SOURCE_ONLY:-}" ] && return 0

while :; do
    tick
    sleep "$poll" &
    wait $!
done
