#!/usr/bin/env bash
# Starts runner-gate.sh for one runner directory unless it already runs, and
# returns at once. Usage: runner-start.sh <runner-dir>
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
slug="$(basename -- "$dir")"
prefix="${RUNNER_PID_PREFIX:-dotfiles-runner}"
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

# Idle system sleep resets the runner's long poll to GitHub, which then shows it
# offline. caffeinate -i blocks only idle sleep, holds for the gate's whole
# life (its waits included), and needs no privilege. Without it (a non-macOS
# test host) the gate runs bare.
awake=()
caffeinate="${RUNNER_CAFFEINATE:-/usr/bin/caffeinate}"
[ -x "$caffeinate" ] && awake=("$caffeinate" -i)

# No nohup, and no other wrapper that ignores SIGHUP: every job would inherit
# the ignored disposition, which breaks the signal handling jobs test. Job
# control (set -m) is what keeps the background start from ignoring SIGINT, as a
# bare `&` in a script does, and puts the gate in its own process group so a
# hangup aimed at the starter's cannot reach it. The expansion form keeps an
# empty array legal under set -u on macOS bash 3.2.
set -m
${low_io[@]+"${low_io[@]}"} nice -n "$nice_level" \
    ${awake[@]+"${awake[@]}"} "$gate" "$dir" \
    >>"$cache/$prefix-$slug.out" 2>>"$cache/$prefix-$slug.err" </dev/null &
echo $! >"$pidfile"
