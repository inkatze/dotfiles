#!/usr/bin/env bash
# Runs postgres-gate.sh's start, role and stop decisions against stubbed
# pg_ctl, psql, createuser, ioreg and sysctl: the server starts only on an idle,
# lightly loaded Mac, is stopped with a fast shutdown when the owner returns,
# survives load alone, the role is created only when missing, and its password
# reaches psql on stdin and nowhere else.
set -eu

repo="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
gate="$repo/roles/osx/files/runner/postgres-gate.sh"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
stubs="$scratch/bin"
data="$scratch/data"
sock="$scratch/run"
mkdir -p "$stubs" "$data" "$sock"

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
# pg_ctl keeps the server's state in a file, and logs each call.
cat >"$stubs/pg_ctl" <<'STUB'
#!/bin/sh
echo "pg_ctl $*" >>"$STUB_LOG"
case " $* " in
    *" status "*) [ -f "$STUB_STATE" ] ;;
    *" start"*) : >"$STUB_STATE" ;;
    *" stop"*) rm -f "$STUB_STATE" ;;
esac
STUB
# psql logs its arguments; stdin goes to a separate file, as a script on stdin.
cat >"$stubs/psql" <<'STUB'
#!/bin/sh
echo "psql $*" >>"$STUB_LOG"
case " $* " in
    *" -f - "*) cat >>"$STUB_STDIN" ;;
    *) [ -n "${STUB_ROLE_EXISTS-}" ] && echo 1 ;;
esac
exit 0
STUB
cat >"$stubs/createuser" <<'STUB'
#!/bin/sh
echo "createuser $*" >>"$STUB_LOG"
[ -z "${STUB_CREATE_FAIL-}" ]
STUB
chmod +x "$stubs"/*

passed=0 failed=0
check() { # check <label> <command...>
    local label="$1"
    shift
    if "$@"; then
        passed=$((passed + 1)); echo "  ok: $label"
    else
        failed=$((failed + 1)); echo "  FAIL: $label"
    fi
}
logged() { grep -qF -- "$1" "$scratch/log"; }
not_logged() { ! grep -qF -- "$1" "$scratch/log"; }
stdin_has() { grep -qF -- "$1" "$scratch/stdin"; }

# step <idle seconds> <load> [role exists]: the gate's loop body (three times:
# start, role, role again) against the current stub state.
step() {
    : >"$scratch/log"
    : >"$scratch/stdin"
    (
        export PATH="$stubs:$PATH" STUB_LOG="$scratch/log" STUB_STDIN="$scratch/stdin" STUB_STATE="$scratch/running"
        export STUB_IDLE="$1" STUB_LOAD="$2" STUB_ROLE_EXISTS="${3-}"
        export RUNNER_IDLE_SECONDS=300 RUNNER_LOAD_MAX=6 POSTGRES_PORT=5599 POSTGRES_SOCKET_DIR="$sock"
        export STUB_CREATE_FAIL="${STUB_CREATE_FAIL-}" POSTGRES_MAX_CONNECTIONS=180 PGPASSFILE="$scratch/pgpass"
        export POSTGRES_GATE_SOURCE_ONLY=1
        # shellcheck disable=SC1090
        . "$gate" "$data"
        tick
        # A server that came up gets its role on the next pass, retried after.
        tick
        tick
    )
}
running() { [ -f "$scratch/running" ]; }
stopped() { ! running; }

: >"$data/PG_VERSION"
# libpq escapes \ and : in a field; the line below is the secret escaped.
printf 'other:1:*:x:y\nlocalhost:5599:*:fleet:s3cr3t\\:with\\\\colon'"'"'q\n' >"$scratch/pgpass"
chmod 600 "$scratch/pgpass"

step 10 1.0
check "a Mac in use does not start the server" stopped
step 600 9.0
check "a loaded Mac does not start the server" stopped

step 600 1.0
check "an idle, quiet Mac starts it" running
check "it listens on localhost only" logged "listen_addresses=localhost"
check "it uses the configured port" logged "port=5599"
check "it opens its socket in the account's own directory" logged "unix_socket_directories=$sock"
check "the socket is closed to other accounts" logged "unix_socket_permissions=0700"
check "the connection cap is set" logged "max_connections=180"
check "a missing role is created over the socket as a superuser" logged "createuser -h $sock -p 5599 -s fleet"
check "the stored password is set on the role through stdin" stdin_has "alter role \"fleet\" password 's3cr3t:with\\colon''q'"
check "the password is in no argument" not_logged "s3cr3t"
check "the role's password is set over the socket, not TCP" logged "psql -q -h $sock -p 5599"

step 600 9.0
check "load alone leaves a running server up" running
check "load alone stops nothing" not_logged " stop"

step 10 1.0
check "the owner's return stops it" stopped
check "it stops with a fast shutdown" logged "-m fast"
check "it waits for the shutdown to finish" logged "-w stop"
check "it never signals the server" not_logged "kill"

step 600 1.0 yes
check "it starts again once the Mac is idle" running
check "an existing role is not created again" not_logged "createuser"

rm "$scratch/pgpass"
step 10 1.0
step 600 1.0 yes
check "with no stored password the role is left as it is" not_logged "-f -"

printf 'localhost:5599:*:fleet:\n' >"$scratch/pgpass"
step 10 1.0
step 600 1.0 yes
check "an empty stored password is never applied" not_logged "-f -"

# A role that failed right after the start is retried on the next pass.
rm -f "$scratch/running"
STUB_CREATE_FAIL=1 step 600 1.0 || true
check "a failed role check is retried while the server runs" test "$(grep -c '^createuser' "$scratch/log")" = 2

# A term of the gate stops a running server the same way.
: >"$scratch/log"
(
    export PATH="$stubs:$PATH" STUB_LOG="$scratch/log" STUB_STATE="$scratch/running"
    export POSTGRES_GATE_SOURCE_ONLY=1 POSTGRES_SOCKET_DIR="$sock"
    # shellcheck disable=SC1090
    . "$gate" "$data"
    trap - TERM INT
    server_running && stop_server
)
check "a running server is stopped fast when the gate is" stopped

# Settings that reach a SQL statement or a server option are refused.
refuses() { # refuses <VAR=value>...
    local kv
    ! (
        export PATH="$stubs:$PATH" POSTGRES_SOCKET_DIR="$sock" POSTGRES_GATE_SOURCE_ONLY=1
        for kv in "$@"; do export "${kv?}"; done
        # shellcheck disable=SC1090
        . "$gate" "$data"
    ) 2>/dev/null
}
check "a role with a quote is refused" refuses "POSTGRES_ROLE=x'; drop"
check "a role starting with a digit is refused" refuses POSTGRES_ROLE=1x
check "a non-numeric port is refused" refuses POSTGRES_PORT=54a
check "a non-numeric connection cap is refused" refuses POSTGRES_MAX_CONNECTIONS=1e3
check "a relative socket directory is refused" refuses POSTGRES_SOCKET_DIR=run
check "a socket directory with a space is refused" refuses "POSTGRES_SOCKET_DIR=/a b"

rm "$data/PG_VERSION"
step 600 1.0 2>"$scratch/err" || true
check "no cluster, no start" stopped
check "no cluster is reported" grep -q "no cluster" "$scratch/err"

echo "postgres-gate: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
