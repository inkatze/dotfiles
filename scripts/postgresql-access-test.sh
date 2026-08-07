#!/usr/bin/env bash
# Verifies the two halves of specs/dev-services Task 3 that only a provisioned
# server can answer (REQ-A1.1, REQ-A1.3, REQ-A1.4, D-4):
#
#   Access   -- the invoking unprivileged account connects over the Unix
#               socket with no password and no credential file, is
#               authenticated as itself, and can create a scratch database,
#               migrate it, and drop it again.
#   Binding  -- whatever the server listens on over TCP is loopback, so it
#               accepts no connection on a routable interface.
#
# Companion to scripts/services-declaration-test.sh, which asserts the role is
# written correctly and runs anywhere. This one asserts the result works, and
# so needs a host where the provisioning has actually run: Task 6's CI job and
# Task 7's host convergence are its two callers.
#
# Every precondition it cannot meet is a non-zero exit naming the fault, never
# a quiet pass. A verification script that exits 0 having proved nothing is
# worse than no script at all, because the green log reports coverage that
# does not exist -- the posture REQ-D1.4 takes toward the Task 1 generator,
# applied to the thing being verified rather than to the thing generating it.
#
# Run: scripts/postgresql-access-test.sh
# Exit 0 = every assertion passed.
set -euo pipefail

fails=0
pass() { echo "ok[$1]: $2"; }
fail() {
    echo "FAIL[$1]: $2" >&2
    fails=$((fails + 1))
}
# "$*", not "$1": the refusals below are written across two arguments so they
# fit on a line here, and a one-argument echo would silently print half of
# each -- dropping exactly the half that says what to do about it.
refuse() {
    echo "REFUSED: $*" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Fixture. REQ-A1.4 is that no password is *needed*, which a run cannot
# demonstrate while a password is within reach: libpq would find it, the
# connection would succeed, and the log would look identical. The absence is
# therefore part of the fixture rather than incidental to it, and is checked
# before anything else so that a compromised environment is reported even on a
# machine with no server to test against.
# ---------------------------------------------------------------------------

for var in PGPASSWORD PGPASSFILE; do
    if [[ -n "${!var:-}" ]]; then
        refuse "$var is set; with a password available this cannot prove REQ-A1.4's" \
            "passwordless access. Unset it and re-run."
    fi
done

if [[ -e "$HOME/.pgpass" ]]; then
    refuse "$HOME/.pgpass exists; with a credential file available this cannot prove" \
        "REQ-A1.4's passwordless access. Move it aside and re-run."
fi

# Cleared rather than merely unset above: these redirect a connection, and the
# point of the run is which connection is being made. --host and --dbname are
# passed explicitly on every call below, so this only closes the gap for the
# ones that have no flag here.
unset PGHOST PGPORT PGDATABASE PGUSER PGSERVICE PGOPTIONS

if [[ "$(id -u)" -eq 0 ]]; then
    refuse "running as root. REQ-A1.4 is about an unprivileged account, and root" \
        "peer-authenticates as a different role entirely."
fi

if ! command -v psql >/dev/null 2>&1; then
    refuse "psql is not on PATH, so there is no server to test. Provision the" \
        "services role on this host first (mise run services)."
fi

if ! command -v ss >/dev/null 2>&1; then
    refuse "ss is not on PATH; the loopback-binding assertion needs it."
fi

# The distribution's socket directory. Named explicitly rather than left to
# libpq's default so the run cannot silently fall back to a TCP connection and
# report it as the socket one.
socket_dir=/var/run/postgresql
if [[ ! -d "$socket_dir" ]]; then
    refuse "$socket_dir does not exist; the server is not installed, or does not" \
        "place its socket where the distribution packaging does."
fi

os_user=$(id -un)
scratch="dotfiles_scratch_$$"

# --no-password makes an unexpected password request an immediate failure
# rather than a prompt: unattended, a prompt on a closed stdin is a hang or a
# confusing EOF, and either obscures the thing actually being tested.
psql_args=(--no-psqlrc --no-password --no-align --tuples-only
    --set=ON_ERROR_STOP=1 --host="$socket_dir")

cleanup() {
    dropdb --no-password --host="$socket_dir" --if-exists "$scratch" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Access (REQ-A1.4).
# ---------------------------------------------------------------------------

connected_as=$(psql "${psql_args[@]}" --dbname=postgres --command='SELECT current_user' 2>&1) || {
    fail "socket-connect" "could not connect over $socket_dir as $os_user:
$(sed 's/^/    /' <<<"$connected_as")"
    echo "postgresql-access-test: $fails assertion(s) failed" >&2
    exit 1
}

# Asserted rather than assumed from the exit status: connecting proves a
# connection, and this proves peer authentication mapped the OS account to the
# database role of the same name, which is the specific mechanism D-4 chose.
if [[ "$connected_as" != "$os_user" ]]; then
    fail "socket-connect" "connected as database role '$connected_as', expected '$os_user'"
else
    pass "socket-connect" "connected over the Unix socket as '$os_user' with no password"
fi

if ! createdb --no-password --host="$socket_dir" "$scratch" 2>&1; then
    fail "scratch-create" "could not create database '$scratch'"
else
    pass "scratch-create" "created scratch database '$scratch'"

    # A migration rather than a bare connection: REQ-A1.4 is about creating,
    # migrating and dropping, and DDL is where a role short of CREATEDB but
    # holding CONNECT would still look fine up to this point.
    migration=$(
        psql "${psql_args[@]}" --dbname="$scratch" \
            --command='CREATE TABLE widgets (id serial PRIMARY KEY, name text NOT NULL)' \
            --command="INSERT INTO widgets (name) VALUES ('first')" \
            --command='ALTER TABLE widgets ADD COLUMN note text' \
            --command='SELECT count(*) FROM widgets' 2>&1
    ) || true

    if [[ "$(tail -n1 <<<"$migration")" != "1" ]]; then
        fail "scratch-migrate" "the migration did not leave one row behind:
$(sed 's/^/    /' <<<"$migration")"
    else
        pass "scratch-migrate" "created a table, altered it, and read a row back"
    fi

    if ! dropdb --no-password --host="$socket_dir" "$scratch" 2>&1; then
        fail "scratch-drop" "could not drop database '$scratch'"
    else
        remaining=$(psql "${psql_args[@]}" --dbname=postgres \
            --set=db="$scratch" \
            --command="SELECT count(*) FROM pg_database WHERE datname = :'db'" 2>&1)
        if [[ "$remaining" != "0" ]]; then
            fail "scratch-drop" "'$scratch' survived the drop (pg_database reports $remaining)"
        else
            pass "scratch-drop" "dropped '$scratch' and confirmed it is gone"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Binding (REQ-A1.3). The port is read back from the running server rather
# than written down here: a hardcoded 5432 would keep passing against a
# cluster listening somewhere else, which is the one case where this assertion
# has something to say.
# ---------------------------------------------------------------------------

port=$(psql "${psql_args[@]}" --dbname=postgres --command='SHOW port' 2>/dev/null || true)
if [[ ! "$port" =~ ^[0-9]+$ ]]; then
    fail "loopback-only" "could not read the server's port back from it (got '$port')"
else
    # Field 4 of `ss -ltn` is the local address and port; ss brackets IPv6, so
    # loopback is `127.0.0.1` or `[::1]` and a wildcard bind reads `0.0.0.0`
    # or `[::]`. Anything on this port that is not one of the two loopback
    # forms is reachable from off the box.
    #
    # Zero TCP listeners also satisfies the requirement -- a socket-only
    # cluster accepts no non-loopback connection either -- so it passes, with
    # the count said out loud rather than left ambiguous.
    #
    # Matched as an anchored suffix rather than by offset arithmetic: the port
    # has to be the end of the field, and `:5432` also appears in the middle
    # of `0.0.0.0:15432`. One capture of `ss`, read twice, so the count and
    # the offenders cannot disagree about a socket that opened between them.
    sockets=$(ss -ltn 2>/dev/null || true)
    listeners=$(awk -v p="$port" 'NR > 1 && $4 ~ ":" p "$" { n++ } END { print n + 0 }' \
        <<<"$sockets")
    routable=$(awk -v p="$port" '
        NR > 1 && $4 ~ ":" p "$" {
            addr = substr($4, 1, length($4) - length(p) - 1)
            if (addr != "127.0.0.1" && addr != "[::1]") { print $4 }
        }' <<<"$sockets")
    if [[ -n "$routable" ]]; then
        fail "loopback-only" "port $port is bound on non-loopback address(es):
$(sed 's/^/    /' <<<"$routable")"
    else
        pass "loopback-only" "port $port has $listeners listener(s), all loopback"
    fi
fi

if [[ "$fails" -ne 0 ]]; then
    echo "postgresql-access-test: $fails assertion(s) failed" >&2
    exit 1
fi
echo "postgresql-access-test: all assertions passed"
