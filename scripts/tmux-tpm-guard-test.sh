#!/usr/bin/env bash
# Asserts tmux.conf's tpm guard against the failure it exists for: a private
# or session-less server must not run tpm, and a server killed while tpm's
# children still run must leave no process behind and start no new server.
# The normal default-socket server must still load its plugins, on a fresh
# start and on a manual `source-file`.
#
# Usage: tmux-tpm-guard-test.sh [<tmux.conf>]
#   Defaults to the tracked conf. Pass an unguarded conf (main's before the
#   guard) to watch the incident cases fail.
#
# Every server lives at an explicit -S path under a scratch directory, with
# TMUX unset and a scratch HOME, so neither the operator's servers nor the
# real default socket are ever addressed. The fake tpm reproduces the real
# one's hazard: a background child that outlives the server and keeps calling
# `tmux list-keys`, a command that starts a server. It stops spawning children
# after a few runs, so an unguarded conf cannot loop forever.
set -uo pipefail

here="$(cd -- "$(dirname "$0")" && pwd -P)"
repo="$(cd -- "$here/.." && pwd -P)"
conf="${1:-$repo/roles/tmux/files/tmux.conf}"
fails=0

if ! command -v tmux >/dev/null 2>&1; then
    echo "tmux-tpm-guard-test: tmux not on PATH" >&2
    exit 2
fi
if [ ! -r "$conf" ]; then
    echo "tmux-tpm-guard-test: cannot read $conf" >&2
    exit 2
fi
conf="$(cd -- "$(dirname "$conf")" && pwd -P)/$(basename "$conf")"

# /tmp, not $TMPDIR: macOS caps a unix socket path near 104 bytes.
scratch="$(mktemp -d /tmp/tpmguard.XXXXXX)"
home="$scratch/home"
runs="$scratch/runs"
mkdir -p "$home/.tmux/plugins/tpm" "$scratch/sock" "$scratch/empty"
: >"$runs"
ln -s "$repo/roles/tmux/files/scripts" "$home/.tmux/scripts"
# As the role links it: a server started by a bare `tmux list-keys` gets no
# -f, so this is the config a re-spawned server loads.
ln -s "$conf" "$home/.tmux.conf"

cat >"$home/.tmux/plugins/tpm/tpm" <<'FAKE'
#!/bin/sh
echo "${TMUX%%,*}" >>"$HOME/../runs"
n=$(wc -l <"$HOME/../runs")
[ $((n)) -le 5 ] || exit 0
(
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        sleep 0.2
        tmux list-keys >/dev/null 2>&1
    done
) &
FAKE
chmod +x "$home/.tmux/plugins/tpm/tpm"

tm() {
    env -u TMUX -u TMUX_PANE -u XDG_CONFIG_HOME \
        HOME="$home" TMUX_TMPDIR="$scratch/sock" tmux "$@"
}

sockets() { find "$scratch/sock" "$scratch/empty" -type s 2>/dev/null; }
live_servers() {
    local s
    sockets | while read -r s; do
        tm -N -S "$s" list-sessions >/dev/null 2>&1 && printf '%s ' "$s"
    done
}
# Every fake tpm and its children carry the scratch path in their command line.
leftover_procs() { pgrep -f -- "$scratch" | tr '\n' ' '; }

# Kills only what this suite started: processes naming the scratch path and
# servers on its sockets, repeated to catch a server re-spawned mid-sweep.
sweep() {
    local s
    for _ in 1 2 3; do
        pkill -f -- "$scratch" 2>/dev/null
        sockets | while read -r s; do tm -N -S "$s" kill-server 2>/dev/null; done
        sleep 0.2
    done
    find "$scratch/sock" "$scratch/empty" -type s -delete 2>/dev/null
    : >"$runs"
}
trap 'sweep; rm -rf "$scratch"' EXIT

pass() { echo "ok[$1]: $2"; }
fail() { echo "FAIL[$1]: $2" >&2; fails=$((fails + 1)); }

runs_for() { grep -cFx -- "$1" "$runs"; }

# Waits up to five seconds for the socket's run count to reach $2.
wait_runs() {
    for _ in $(seq 50); do
        [ "$(runs_for "$1")" -ge "$2" ] && return 0
        sleep 0.1
    done
    return 1
}

# The fake child loops for two seconds; three covers it with margin.
settle() { sleep 3; }

expect_no_leftovers() {
    local case="$1" what="$2" left alive
    left="$(leftover_procs)"
    if [ -z "$left" ]; then pass "$case" "no process outlived the $what"; else fail "$case" "processes outlived the $what: $left"; fi
    alive="$(live_servers)"
    if [ -z "$alive" ]; then pass "$case" "no server re-spawned"; else fail "$case" "live server(s) at: $alive"; fi
}

# 1. The incident: a private server, killed a moment after it starts.
probe="$scratch/sock/probe"
tm -S "$probe" -f "$conf" new-session -d -s probe 'sleep 600'
sleep 0.3
tm -N -S "$probe" kill-server 2>/dev/null
settle
n="$(wc -l <"$runs" | tr -d ' ')"
if [ "$n" -eq 0 ]; then pass 1 "tpm never ran for a private socket"; else fail 1 "tpm ran $n time(s) after a private server started"; fi
expect_no_leftovers 1 "private server"
sweep

# 2. A default-named server with no session, started the way the chain started
# each of its servers: by bare `tmux list-keys` calls, repeated as the
# outliving children repeated them.
empty="$scratch/empty/default"
for _ in $(seq 10); do
    tm -S "$empty" list-keys >/dev/null 2>&1
    sleep 0.2
done
settle
n="$(runs_for "$empty")"
if [ "$n" -eq 0 ]; then pass 2 "tpm never ran on a server with no session"; else fail 2 "tpm ran $n time(s) on a server with no session"; fi
expect_no_leftovers 2 "session-less server"
sweep

# 3. The normal server: a fresh start loads plugins.
main="$scratch/sock/default"
tm -S "$main" -f "$conf" new-session -d -s main 'sleep 600'
if wait_runs "$main" 1; then pass 3 "tpm ran on a fresh default-socket start"; else fail 3 "tpm did not run on a fresh default-socket start"; fi

# 4. A manual source-file on that server loads them again.
tm -N -S "$main" source-file "$conf"
if wait_runs "$main" 2; then pass 4 "tpm ran again on source-file"; else fail 4 "tpm did not run on source-file"; fi

# 5. Killed while tpm's children still run, the server must stay dead.
before="$(runs_for "$main")"
tm -N -S "$main" kill-server 2>/dev/null
settle
after="$(runs_for "$main")"
if [ "$after" -eq "$before" ]; then pass 5 "tpm's children did not re-spawn the killed server"; else fail 5 "tpm ran $((after - before)) more time(s) after the server was killed"; fi
expect_no_leftovers 5 "killed server"

if [ "$fails" -gt 0 ]; then
    echo "tmux-tpm-guard-test: $fails failure(s)" >&2
    exit 1
fi
echo "tmux-tpm-guard-test: all passed"
