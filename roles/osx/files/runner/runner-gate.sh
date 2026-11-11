#!/usr/bin/env bash
# Runs one GitHub Actions runner directory as a courtesy tenant of a Mac
# someone else uses. Usage: runner-gate.sh <runner-dir>
#
# The runner takes work only while the Mac is free: the keyboard and mouse have
# been still for RUNNER_IDLE_SECONDS and the one-minute load average is under
# RUNNER_LOAD_MAX. Whoever owns the console does not matter: a Mac left logged
# in and untouched serves jobs. The listener runs with --once, so it accepts at
# most one job and exits; this loop starts the next only after re-checking.
# While the Mac is in use and no job has started, the listener is stopped and
# the runner shows offline. A job already running is never interrupted: it
# finishes niced (the agent's priority is inherited), and nothing new starts.
set -u

dir="${1:?usage: runner-gate.sh <runner-dir>}"
idle_needed="${RUNNER_IDLE_SECONDS:-300}"
load_max="${RUNNER_LOAD_MAX:-6}"
poll="${RUNNER_POLL_SECONDS:-10}"

# Nanoseconds since the last HID event; empty when it cannot be read, which
# counts as busy.
hid_idle_seconds() {
    ioreg -c IOHIDSystem 2>/dev/null |
        awk '/"HIDIdleTime"/ { print int($NF / 1000000000); exit }'
}

# One-minute load average from `{ 1m 5m 15m }`; empty when unreadable, which
# counts as busy.
load_one_minute() { sysctl -n vm.loadavg 2>/dev/null | awk '{ print $2; exit }'; }

mac_is_free() {
    local idle load
    idle="$(hid_idle_seconds)"
    [ -n "$idle" ] && [ "$idle" -ge "$idle_needed" ] || return 1
    load="$(load_one_minute)"
    [ -n "$load" ] && awk -v l="$load" -v m="$load_max" 'BEGIN { exit !(l + 0 < m + 0) }'
}

job_running() { pgrep -f "$dir/bin/Runner.Worker" >/dev/null 2>&1; }

listener=""
stop_listener() {
    if [ -n "$listener" ]; then
        # run.sh hands off to a helper and the listener below it, so signalling
        # run.sh alone would leave the listener taking jobs.
        pkill -TERM -f "$dir/bin/Runner.Listener" 2>/dev/null
        kill "$listener" 2>/dev/null
        wait "$listener" 2>/dev/null
        listener=""
    fi
}
trap 'stop_listener; exit 0' TERM INT

# Lets the test source the decision functions without starting the loop.
[ -n "${RUNNER_GATE_SOURCE_ONLY:-}" ] && return 0

cd "$dir" || exit 1
while :; do
    if [ -z "$listener" ]; then
        if mac_is_free; then
            ./run.sh --once &
            listener=$!
        fi
    elif ! kill -0 "$listener" 2>/dev/null; then
        wait "$listener" 2>/dev/null
        listener=""
    elif ! mac_is_free && ! job_running; then
        stop_listener
    fi
    sleep "$poll" &
    wait $!
done
