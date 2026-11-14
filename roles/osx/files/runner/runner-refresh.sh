#!/bin/sh
# Stops a runner's idle listener so its gate starts a fresh one that reads the
# runner's current .env and .path. Usage: runner-refresh.sh <runner-dir>
#
# A listener serving a job is left alone: it runs with --once, exits after the
# job, and the gate's next start reads the new files anyway. Nothing runs when
# no listener does.
set -eu

dir="${1:?usage: runner-refresh.sh <runner-dir>}"

if pgrep -f "$dir/bin/Runner.Worker" >/dev/null 2>&1; then exit 0; fi
pkill -TERM -f "$dir/bin/Runner.Listener" >/dev/null 2>&1 || true
