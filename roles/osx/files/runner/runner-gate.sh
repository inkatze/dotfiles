#!/usr/bin/env bash
# Runs one GitHub Actions runner directory as a courtesy tenant of a Mac
# someone else uses. Usage: runner-gate.sh <runner-dir>
#
# The runner takes work only while the Mac is idle: the console belongs to this
# account, the login window or nobody, and the keyboard and mouse have been
# still for RUNNER_IDLE_SECONDS. The listener runs with --once, so it accepts at
# most one job and exits; this loop starts the next only after re-checking.
# While the Mac is in use and no job has started, the listener is stopped and
# the runner shows offline. A job already running is never interrupted: it
# finishes niced (the agent's priority is inherited), and nothing new starts.
set -u

dir="${1:?usage: runner-gate.sh <runner-dir>}"
idle_needed="${RUNNER_IDLE_SECONDS:-300}"
poll="${RUNNER_POLL_SECONDS:-10}"
me="$(id -un)"

# Nanoseconds since the last HID event; empty when it cannot be read, which
# counts as busy.
hid_idle_seconds() {
    ioreg -c IOHIDSystem 2>/dev/null |
        awk '/"HIDIdleTime"/ { print int($NF / 1000000000); exit }'
}

console_user() { stat -f %Su /dev/console 2>/dev/null; }

mac_is_free() {
    local owner idle
    owner="$(console_user)"
    case "$owner" in
        "$me" | root | '') ;;
        *) return 1 ;;
    esac
    idle="$(hid_idle_seconds)"
    [ -n "$idle" ] && [ "$idle" -ge "$idle_needed" ]
}

job_running() { pgrep -f "$dir/bin/Runner.Worker" >/dev/null 2>&1; }

listener=""
stop_listener() {
    if [ -n "$listener" ]; then
        kill "$listener" 2>/dev/null
        wait "$listener" 2>/dev/null
        listener=""
    fi
}
trap 'stop_listener; exit 0' TERM INT

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
