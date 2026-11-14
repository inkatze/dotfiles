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
    pkill -f "$scratch/" 2>/dev/null || true
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

# RUNNER_PID_PREFIX names the pid, lock and log files, leaving the default's alone.
kill "$(cat "$pidfile")" 2>/dev/null || true; sleep 0.3
RUNNER_PID_PREFIX=other "$start" "$scratch/r"
settle 5
check "a prefix names its own pid file" test -s "$scratch/cache/other-r.pid"
check "a prefix names its own log file" test -f "$scratch/cache/other-r.out"
kill "$(cat "$scratch/cache/other-r.pid")" 2>/dev/null || true

# The gate runs under caffeinate -i, so idle sleep cannot drop the runner's
# connection; without caffeinate it still starts.
cat >"$scratch/caffeinate" <<'STUB'
#!/bin/sh
echo "caffeinate $*" >>"$(dirname "$0")/awake"
exec "$@"
STUB
chmod +x "$scratch/caffeinate"
RUNNER_CAFFEINATE="$scratch/caffeinate" RUNNER_PID_PREFIX=awake "$start" "$scratch/r"
settle 6
check "the gate starts under caffeinate -i" \
    grep -qx "caffeinate -i $scratch/gate.sh $scratch/r" "$scratch/awake"
kill "$(cat "$scratch/cache/awake-r.pid")" 2>/dev/null || true; sleep 0.3
check "a missing caffeinate leaves the gate starting bare" starts_is 5

# The gate must see SIGHUP and SIGINT at their defaults, as every job inherits
# them: a nohup (or a bare background start) would leave one ignored.
cat >"$scratch/sig-gate.sh" <<'STUB'
#!/usr/bin/env bash
trap -p HUP INT >"$(dirname "$0")/sig"
echo "started $1" >>"$(dirname "$0")/starts"
sleep 60
STUB
chmod +x "$scratch/sig-gate.sh"
RUNNER_GATE="$scratch/sig-gate.sh" RUNNER_PID_PREFIX=sig "$start" "$scratch/r"
settle 7
check "the gate sees SIGHUP and SIGINT at their defaults" test -f "$scratch/sig" -a ! -s "$scratch/sig"
kill "$(cat "$scratch/cache/sig-r.pid")" 2>/dev/null || true
grep -v '^[[:space:]]*#' "$start" >"$scratch/start.code"
check "the start path carries no nohup or HUP-ignoring wrapper" \
    sh -c '! grep -Eiq "nohup|trap +.. +(HUP|1)|SIG_IGN" "$1"' _ "$scratch/start.code"
check "no pmset call exists anywhere in the osx role" \
    sh -c '! grep -rIl "pmset" "$1/roles/osx"' _ "$repo"

# A work directory behind a .noindex name is skipped by Spotlight: an existing
# `_work` moves behind a symlink, a fresh runner's is left alone, a running job
# stops the move, and a second run changes nothing.
wd="$repo/roles/osx/files/runner/runner-workdir.sh"
mkdir -p "$scratch/w/old/_work/repo" "$scratch/w/new" "$scratch/w/busy/_work" "$scratch/w/bin"
echo data >"$scratch/w/old/_work/repo/file"
echo '{ "workFolder": "_work" }' >"$scratch/w/old/.runner"
echo '{ "workFolder": "_work.noindex" }' >"$scratch/w/new/.runner"
echo '{ "workFolder": "_work" }' >"$scratch/w/busy/.runner"
cat >"$scratch/w/bin/pgrep" <<'STUB'
#!/bin/sh
case "$*" in *"/busy/bin/Runner.Worker"*) exit 0 ;; esac
exit 1
STUB
chmod +x "$scratch/w/bin/pgrep"
workdir() { PATH="$scratch/w/bin:$PATH" "$wd" "$scratch/w/$1"; }
check "an existing work directory moves behind .noindex" \
    test "$(workdir old)" = moved -a -L "$scratch/w/old/_work" -a -f "$scratch/w/old/_work.noindex/repo/file"
check "the symlinked work directory still reads through" test -f "$scratch/w/old/_work/repo/file"
check "a second run changes nothing" test -z "$(workdir old)"
check "a runner registered under .noindex is left alone" \
    test -z "$(workdir new)" -a ! -e "$scratch/w/new/_work"
check "a running job stops the move" \
    test -z "$(workdir busy)" -a -d "$scratch/w/busy/_work" -a ! -L "$scratch/w/busy/_work"

# A changed runner's idle listener is stopped so its gate starts one with the new
# environment; one serving a job is left to finish; no listener, no error.
refresh="$repo/roles/osx/files/runner/runner-refresh.sh"
mkdir -p "$scratch/f/bin"
cat >"$scratch/f/bin/pgrep" <<'STUB'
#!/bin/sh
[ -n "${STUB_WORKER-}" ] && exit 0
exit 1
STUB
cat >"$scratch/f/bin/pkill" <<'STUB'
#!/bin/sh
echo "$*" >>"$(dirname "$0")/pkills"
exit 1
STUB
chmod +x "$scratch/f/bin/"*
PATH="$scratch/f/bin:$PATH" "$refresh" /r/x
check "an idle listener is stopped" grep -qx -- "-TERM -f /r/x/bin/Runner.Listener" "$scratch/f/bin/pkills"
rm -f "$scratch/f/bin/pkills"
PATH="$scratch/f/bin:$PATH" STUB_WORKER=1 "$refresh" /r/x
check "a listener serving a job is left alone" test ! -e "$scratch/f/bin/pkills"

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

# The hook is installed before any gate is scheduled, and each runner's .env and
# .path are written after registration (config.sh rewrites both) and before the
# gates; an idle listener started earlier is restarted when either changed.
order() { python3 - "$repo" <<'PY'; }
import sys, yaml
tasks = yaml.safe_load(open(f"{sys.argv[1]}/roles/osx/tasks/offload-runner.yml"))
names = [t["name"] for t in tasks]
defaults_text = open(f"{sys.argv[1]}/roles/osx/defaults/main.yml").read()
def at(n): return names.index(n)
bad = []
def line_task(key):
    return [t for t in tasks if "ansible.builtin.lineinfile" in t
            and key in t["ansible.builtin.lineinfile"].get("line", "")]
hook = line_task("ACTIONS_RUNNER_HOOK_JOB_STARTED=")
npm_env = line_task("NPM_CONFIG_PREFIX=")
npm_path = line_task("osx_runner_job_path_prefix")
if len(npm_env) != 1 or not npm_env[0]["ansible.builtin.lineinfile"]["path"].endswith("/.env"):
    bad.append("no single .env line setting NPM_CONFIG_PREFIX")
elif not (at("Register each unregistered runner") < at(npm_env[0]["name"]) < at("Start each runner's gate at boot")):
    bad.append("NPM_CONFIG_PREFIX not written after registration and before the gates")
if len(npm_path) != 1 or not npm_path[0]["ansible.builtin.lineinfile"]["path"].endswith("/.path"):
    bad.append("no single .path line putting the npm prefix first")
else:
    n = npm_path[0]
    if not (at("Register each unregistered runner") < at(n["name"]) < at("Start each runner's gate at boot")):
        bad.append(".path prefix is not written after registration and before start")
    if "osx_runner_npm_prefix" not in defaults_text.split("osx_runner_job_path_prefix:")[1].splitlines()[0] or "osx_runner_node_bin" not in defaults_text.split("osx_runner_job_path_prefix:")[1].splitlines()[0]:
        bad.append("the job PATH prefix lacks the npm prefix or the node bin")
    if not any(t["name"] == "Install the runners' node" and at(t["name"]) < at(n["name"]) for t in tasks):
        bad.append("the node is not installed before the .path prefix")
    if not n["ansible.builtin.lineinfile"].get("backrefs"):
        bad.append(".path prefix is not idempotent (needs backrefs)")
if len(hook) != 1:
    bad.append("no single .env line setting ACTIONS_RUNNER_HOOK_JOB_STARTED")
else:
    l = hook[0]["ansible.builtin.lineinfile"]["line"].strip()
    if not l.startswith("ACTIONS_RUNNER_HOOK_JOB_STARTED={{ ansible_facts.env.HOME }}/"):
        bad.append("hook path is not absolute")
    if at(hook[0]["name"]) < at("Register each unregistered runner"):
        bad.append("hook .env line written before registration, which can rewrite .env")
    for later in ("Start each runner's gate at boot", "Start each runner's gate now"):
        if at(hook[0]["name"]) > at(later):
            bad.append(f"hook .env line written after: {later}")
inst = [t for t in tasks if t["name"] == "Install each runner's job-started hook"]
if not inst or at(inst[0]["name"]) > at(hook[0]["name"]):
    bad.append("hook not installed before the .env line")
if any(t.get("ignore_errors") or t.get("failed_when") is False for t in inst + hook):
    bad.append("hook install may be ignored on failure")
units = [t for t in tasks if t["name"] == "Fix the runner instances"]
if not units or "osx_runner_instances" not in str(units[0]):
    bad.append("runner instances do not come from osx_runner_instances")
defaults = yaml.safe_load(open(f"{sys.argv[1]}/roles/osx/defaults/main.yml"))
if defaults.get("osx_runner_instances", {}).get("inkatze/planwright") != 4:
    bad.append("planwright is not set to four instances")
for t in tasks:
    if ("ansible.builtin.cron" in t or "ansible.builtin.copy" in t or "ansible.builtin.lineinfile" in t) \
            and "osx_runner_all_repos" in str(t):
        bad.append(f"{t['name']}: loops over repositories, not instances")
legacy = [t for t in tasks if t["name"] == "Retire the hand-set runner crontab lines"]
if not legacy or at(legacy[0]["name"]) > at("Start each runner's gate at boot"):
    bad.append("hand-set crontab lines not retired before the gates are scheduled")
reg = [t for t in tasks if t["name"] == "Register each unregistered runner"][0]
argv = reg["ansible.builtin.command"]["argv"]
if "{{ item.item.item.name }}" not in argv or "{{ osx_runner_labels }}" not in argv:
    bad.append("registration does not use the unit's name and the shared labels")
if "--replace" not in argv:
    bad.append("registration does not replace a same-named runner")
if reg["ansible.builtin.command"].get("creates") != "{{ item.item.item.dir }}/.runner":
    bad.append("an already registered directory is not left alone")
if "offload-mac-ci" not in defaults["osx_runner_labels"].split(",") or "mac-fleet" not in defaults["osx_runner_labels"].split(","):
    bad.append("labels lack mac-fleet or offload-mac-ci")
if defaults["osx_runner_name"] != "offload-mac-ci" or "osx_runner_name" not in str(units[0]):
    bad.append("runner names do not follow the live offload-mac-ci, -2, -3, -4")
if "--work" not in argv or argv[argv.index("--work") + 1] != "_work.noindex":
    bad.append("registration does not put the work directory under .noindex")
wd = [t for t in tasks if t["name"] == "Keep each runner's work directory out of Spotlight"]
if not wd or not (at("Register each unregistered runner") < at(wd[0]["name"]) < at("Start each runner's gate at boot")):
    bad.append("existing runners' work directories are not moved after registration and before the gates")
inst2 = [t for t in tasks if t["name"] == "Install the runner gate and start scripts"][0]
if "runner-workdir.sh" not in inst2["ansible.builtin.copy"]["src"] and "runner-workdir.sh" not in inst2["loop"]:
    bad.append("runner-workdir.sh is not installed")
ref = [t for t in tasks if t["name"] == "Restart each changed runner's idle listener"]
if not ref or not (at("Put each runner's npm prefix and node first on its job PATH") < at(ref[0]["name"]) < at("Start each runner's gate at boot")):
    bad.append("no listener restart between the .env/.path writes and the gates")
else:
    cond = str(ref[0].get("when"))
    for reg in ("osx_runner_hook_env", "osx_runner_npm_env", "osx_runner_jobs_env", "osx_runner_job_path"):
        if reg not in cond:
            bad.append(f"listener restart ignores {reg}")
if not any(t["name"] == "Require the system jq the job-started hook reads payloads with"
           and at(t["name"]) < at("Install each runner's job-started hook") for t in tasks):
    bad.append("the play does not require /usr/bin/jq before installing the hook")
jobs = line_task("PLANWRIGHT_TEST_JOBS=")
if len(jobs) != 1 or not jobs[0]["ansible.builtin.lineinfile"]["path"].endswith("/.env"):
    bad.append("no single .env line setting PLANWRIGHT_TEST_JOBS")
elif not (at("Register each unregistered runner") < at(jobs[0]["name"]) < at("Start each runner's gate at boot")):
    bad.append("PLANWRIGHT_TEST_JOBS not written after registration and before the gates")
import jinja2
tmpl = jinja2.Environment().from_string(str(defaults["osx_runner_test_jobs"]))
def jobs_for(cores):
    return int(tmpl.render(ansible_facts={"processor_vcpus": cores}, item={"repo": "o/r"}).strip())
for cores, want in ((16, 8), (2, 1), (1, 1), (10, 5)):
    if jobs_for(cores) != want:
        bad.append(f"{cores} cores gives {jobs_for(cores)} test jobs, not {want}")
prefix_t = jinja2.Environment().from_string(str(defaults["osx_runner_npm_prefix"]))
home = {"env": {"HOME": "/h"}}
prefixes = [prefix_t.render(ansible_facts=home, item={"n": n}) for n in (1, 2, 3, 4)]
if prefixes != [f"/h/.npm-global-{n}" for n in (1, 2, 3, 4)] or len(set(prefixes)) != 4:
    bad.append(f"npm prefixes are not one per instance, numbered by n: {prefixes}")
if "item" not in str(defaults["osx_runner_job_path_prefix"]) + str(defaults["osx_runner_npm_prefix"]):
    bad.append("the job PATH prefix is not per instance")
mk = [t for t in tasks if t["name"] == "Create each runner's own npm prefix"]
if not mk or "osx_runner_units" not in str(mk[0]["loop"]) or "osx_runner_npm_prefix" not in str(mk[0]):
    bad.append("each instance's npm prefix directory is not created")
if bad:
    print("\n".join("    " + b for b in bad)); sys.exit(1)
PY
check "the hook, .env and .path land after registration and before the gates" order

echo "runner-start: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
