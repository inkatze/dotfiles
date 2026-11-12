#!/usr/bin/env bash
# Starts a gate (runner-gate.sh, or RUNNER_GATE) for one directory unless it
# already runs, and returns at once. Usage: runner-start.sh <dir>
# RUNNER_PID_PREFIX names its pid, lock and log files in the cache directory.
#
# The fleet account only ever logs in over ssh, so it has no launchd user
# domain and no sudo: its crontab calls this at boot and every few minutes, and
# whatever it started outlives the cron job and any ssh session. The gate's
# pid file names the one running copy, checked against the process's own
# command line so a recycled pid is not mistaken for it.
set -u

dir="${1:?usage: runner-start.sh <runner-dir>}"
here="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
gate="${RUNNER_GATE:-$here/runner-gate.sh}"
cache="${RUNNER_CACHE_DIR:-$HOME/.cache}"
nice_level="${RUNNER_NICE:-10}"
prefix="${RUNNER_PID_PREFIX:-dotfiles-runner}"
case "$prefix" in '' | *[!A-Za-z0-9_.-]*) echo "runner-start: RUNNER_PID_PREFIX must be a plain name" >&2; exit 1 ;; esac
slug="$(basename -- "$dir")"
pidfile="$cache/$prefix-$slug.pid"
lock="$cache/$prefix-$slug.lock"

mkdir -p "$cache" || exit 1

running() {
    local pid
    pid="$(cat "$pidfile" 2>/dev/null)" || return 1
    case "$pid" in '' | *[!0-9]*) return 1 ;; esac
    ps -p "$pid" -o command= 2>/dev/null | grep -qF -- "$gate $dir"
}

# mkdir is atomic: the boot and periodic jobs can fire in the same second. A
# starter killed mid-run leaves its lock behind, so one older than a few
# minutes is stale.
find "$lock" -maxdepth 0 -mmin +3 -exec rmdir {} + 2>/dev/null
mkdir "$lock" 2>/dev/null || exit 0
trap 'rmdir "$lock" 2>/dev/null' EXIT

running && exit 0

# taskpolicy -b also lowers disk priority, as the old agent's LowPriorityIO did.
low_io=()
command -v taskpolicy >/dev/null 2>&1 && low_io=(taskpolicy -b)

# The expansion form keeps an empty array legal under set -u on macOS bash 3.2.
nohup ${low_io[@]+"${low_io[@]}"} nice -n "$nice_level" "$gate" "$dir" \
    >>"$cache/$prefix-$slug.out" 2>>"$cache/$prefix-$slug.err" </dev/null &
echo $! >"$pidfile"
