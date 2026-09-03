#!/usr/bin/env bash
# PreToolUse(Bash) gate for planwright's worker-command-guard, which
# auto-approves a dispatched fleet worker's routine commands.
#
# Blast radius is enforced by env, not by file placement: without
# PLANWRIGHT_WORKER_HANDLE (exported by the worker launcher) this exits 0 and
# defers to the normal permission flow, so a human or tower session is never
# widened. That is what makes user scope correct here — the gate's lifetime is
# per-machine, and per-project placement left every new worktree without it.
[ -n "${PLANWRIGHT_WORKER_HANDLE:-}" ] || exit 0

# Newest cached version, resolved at exec time so plugin updates need no
# regeneration step here.
root=$(ls -d "$HOME"/.claude/plugins/cache/planwright/planwright/*/ 2>/dev/null | sort -V | tail -1)
root=${root%/}
[ -x "$root/scripts/worker-command-guard.sh" ] || exit 0
exec "$root/scripts/worker-command-guard.sh"
