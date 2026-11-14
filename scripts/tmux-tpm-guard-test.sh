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
# after a few runs, so an unguarded conf cannot loop forever. The last case
# runs the installed tpm instead, to show a plugin still loads through the
# guard; it fails where the tmux role has not installed tpm.
set -uo pipefail

here="$(cd -- "$(dirname "$0")" && pwd -P)"
repo="$(cd -- "$here/.." && pwd -P)"
conf="${1:-$repo/roles/tmux/files/tmux.conf}"
real_home="$HOME"
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
# Must not be empty: the sweep's `pkill -f` pattern is this path, and an empty
# pattern matches every process.
scratch="$(mktemp -d /tmp/tpmguard.XXXXXX)" && [ -n "$scratch" ] || {
    echo "tmux-tpm-guard-test: cannot create a scratch directory" >&2
    exit 2
}
trap 'sweep; rm -rf "$scratch"' EXIT
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
    local label="$1" what="$2" left alive
    left="$(leftover_procs)"
    if [ -z "$left" ]; then pass "$label" "no process outlived the $what"; else fail "$label" "processes outlived the $what: $left"; fi
    alive="$(live_servers)"
    if [ -z "$alive" ]; then pass "$label" "no server re-spawned"; else fail "$label" "live server(s) at: $alive"; fi
}

# 1. The incident: a private server, killed a moment after it starts.
probe="$scratch/sock/probe"
tm -S "$probe" -f "$conf" new-session -d -s probe 'sleep 600'
if tm -N -S "$probe" list-sessions >/dev/null 2>&1; then pass 1 "the private server started"; else fail 1 "the private server did not start"; fi
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
before="$(runs_for "$main")"
tm -N -S "$main" source-file "$conf"
if wait_runs "$main" $((before + 1)); then pass 4 "tpm ran again on source-file"; else fail 4 "tpm did not run on source-file"; fi

# 5. Killed while tpm's children still run, the server must stay dead.
before="$(runs_for "$main")"
tm -N -S "$main" kill-server 2>/dev/null
settle
after="$(runs_for "$main")"
if [ "$after" -eq "$before" ]; then pass 5 "tpm's children did not re-spawn the killed server"; else fail 5 "tpm ran $((after - before)) more time(s) after the server was killed"; fi
expect_no_leftovers 5 "killed server"
sweep

# 6. The real tpm, run through the guard and its -N shim, still sources a
# listed plugin, whose own tmux call reaches the live server.
real_tpm="$real_home/.tmux/plugins/tpm"
if [ ! -x "$real_tpm/tpm" ]; then
    fail 6 "no tpm at $real_tpm (the tmux role installs it)"
else
    home="$scratch/home-real"
    mkdir -p "$home/.tmux/plugins/tmux-sensible"
    ln -s "$repo/roles/tmux/files/scripts" "$home/.tmux/scripts"
    ln -s "$conf" "$home/.tmux.conf"
    ln -s "$real_tpm" "$home/.tmux/plugins/tpm"
    printf '#!/bin/sh\ntmux set -g @tpm_guard_test loaded\n' >"$home/.tmux/plugins/tmux-sensible/sensible.tmux"
    chmod +x "$home/.tmux/plugins/tmux-sensible/sensible.tmux"
    real="$scratch/sock/default"
    tm -S "$real" -f "$conf" new-session -d -s real 'sleep 600'
    tm -N -S "$real" list-sessions >/dev/null 2>&1 || fail 6 "the server did not start"
    got=""
    for _ in $(seq 50); do
        got="$(tm -N -S "$real" show -gqv @tpm_guard_test)"
        [ "$got" = loaded ] && break
        sleep 0.1
    done
    if [ "$got" = loaded ]; then pass 6 "the real tpm sourced a plugin through the guard"; else fail 6 "the real tpm did not source the plugin (got '${got}')"; fi
    tm -N -S "$real" kill-server 2>/dev/null
fi

# 7. The shim alone: against a dead socket it must not start a server.
dead="$scratch/sock/shim-dead"
shim="$repo/roles/tmux/files/scripts/tpm-guard-bin/tmux"
shim_out="$(env -u TMUX HOME="$home" TMUX_TMPDIR="$scratch/sock" TPM_GUARD_REAL_TMUX="$(command -v tmux)" "$shim" -S "$dead" list-keys 2>&1)"
shim_rc=$?
sleep 0.3
if [ "$shim_rc" -ne 0 ] && [ ! -S "$dead" ]; then pass 7 "the shim started no server on a dead socket"; else fail 7 "the shim started a server on a dead socket (exit $shim_rc: $shim_out)"; fi

if [ "$fails" -gt 0 ]; then
    echo "tmux-tpm-guard-test: $fails failure(s)" >&2
    exit 1
fi
echo "tmux-tpm-guard-test: all passed"
