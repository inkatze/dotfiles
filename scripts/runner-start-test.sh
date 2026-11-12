#!/usr/bin/env bash
# Runs runner-start.sh against a stub gate in a scratch directory: it starts one
# copy, leaves a running one alone, replaces a dead or recycled pid, and yields
# to a held lock. Then checks that the role starts the gate from the fleet
# account's crontab and no longer touches launchd.
set -eu

repo="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
start="$repo/roles/osx/files/runner/runner-start.sh"
scratch="$(mktemp -d)"
cleanup() {
    [ -f "$scratch/cache/dotfiles-runner-r.pid" ] &&
        kill "$(cat "$scratch/cache/dotfiles-runner-r.pid")" 2>/dev/null || true
    [ -n "${decoy:-}" ] && kill "$decoy" 2>/dev/null || true
    rm -rf "$scratch"
}
trap cleanup EXIT

mkdir -p "$scratch/r"
# The stub must show "<gate> <dir>" in its command line, as the real gate does.
cat >"$scratch/gate.sh" <<'STUB'
#!/bin/sh
echo "started $1" >>"$(dirname "$0")/starts"
sleep 60
STUB
chmod +x "$scratch/gate.sh"

export RUNNER_GATE="$scratch/gate.sh" RUNNER_CACHE_DIR="$scratch/cache" RUNNER_NICE=10
pidfile="$scratch/cache/dotfiles-runner-r.pid"

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
starts() {
    if [ -f "$scratch/starts" ]; then wc -l <"$scratch/starts" | tr -d ' '; else echo 0; fi
}
starts_is() { [ "$(starts)" = "$1" ]; }
# settle <n>: wait up to five seconds for the nth start to be logged.
settle() { local i=0; while [ "$(starts)" -lt "$1" ] && [ $i -lt 50 ]; do sleep 0.1; i=$((i + 1)); done; }

"$start" "$scratch/r"
settle 1
check "starts the gate once" starts_is 1
check "records its pid" test -s "$pidfile"
check "logs into the cache directory" test -f "$scratch/cache/dotfiles-runner-r.out"

"$start" "$scratch/r"
sleep 0.3
check "a second call leaves the running gate alone" starts_is 1

kill "$(cat "$pidfile")"; sleep 0.3
"$start" "$scratch/r"
settle 2
check "a dead gate is started again" starts_is 2
kill "$(cat "$pidfile")"; sleep 0.3

sleep 60 & decoy=$!
echo "$decoy" >"$pidfile"
"$start" "$scratch/r"
settle 3
check "a recycled pid is not mistaken for the gate" starts_is 3
kill "$decoy"; decoy=
kill "$(cat "$pidfile")"; sleep 0.3

mkdir "$scratch/cache/dotfiles-runner-r.lock"
"$start" "$scratch/r"
sleep 0.3
check "a held lock stops a second starter" starts_is 3
check "a held lock is left in place" test -d "$scratch/cache/dotfiles-runner-r.lock"

touch -t 200001010000 "$scratch/cache/dotfiles-runner-r.lock"
"$start" "$scratch/r"
settle 4
check "a stale lock is cleared and the gate started" starts_is 4

# RUNNER_PID_PREFIX gives another gate its own pid, lock and log names, so the
# postgres gate and a runner never share a pid file.
mkdir -p "$scratch/p"
RUNNER_PID_PREFIX=dotfiles-postgres "$start" "$scratch/p"
settle 5
check "a prefixed gate keeps its pid under the prefix" test -s "$scratch/cache/dotfiles-postgres-p.pid"
check "a prefixed gate leaves the runner names alone" test ! -e "$scratch/cache/dotfiles-runner-p.pid"
kill "$(cat "$scratch/cache/dotfiles-postgres-p.pid")" 2>/dev/null || true

# The role: crontab jobs, no launchd.
contract() { python3 - "$repo" <<'PY'; }
import re, sys, yaml
repo = sys.argv[1]
tasks = yaml.safe_load(open(f"{repo}/roles/osx/tasks/offload-runner.yml"))
defaults = yaml.safe_load(open(f"{repo}/roles/osx/defaults/main.yml"))
text = open(f"{repo}/roles/osx/tasks/offload-runner.yml").read()
bad = []
code = "\n".join(l for l in text.splitlines() if not l.lstrip().startswith("#"))
for word in ("launchctl", "LaunchAgents", "gui/", "runner.plist"):
    if word in code:
        bad.append(f"task file still mentions {word}")
cron = [t["ansible.builtin.cron"] for t in tasks if "ansible.builtin.cron" in t]
if not any(c.get("special_time") == "reboot" for c in cron):
    bad.append("no @reboot cron job")
if not any(str(c.get("minute", "")).startswith("*/") for c in cron):
    bad.append("no periodic re-check cron job")
for c in cron:
    if c["job"] != "{{ osx_runner_start_job }}":
        bad.append(f"cron job {c['job']!r} is not the shared start job")
job = defaults["osx_runner_start_job"]
if "%" in job:
    bad.append("start job holds a % (it ends a cron command)")
for needle in ("PATH=", "RUNNER_IDLE_SECONDS=", "RUNNER_LOAD_MAX=", "RUNNER_NICE=", "runner-start.sh"):
    if needle not in job:
        bad.append(f"start job lacks {needle}")
for t in tasks:
    if "ansible.builtin.cron" in t and "become" in t:
        bad.append("cron task escalates")
if bad:
    print("\n".join("    " + b for b in bad)); sys.exit(1)
PY
check "role starts from the crontab, not launchd" contract

echo "runner-start: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
