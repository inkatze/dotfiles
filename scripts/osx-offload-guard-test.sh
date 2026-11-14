#!/usr/bin/env bash
# Static checks on the osx role's offload-host guards, read from the task files
# with PyYAML (no play runs, so no Mac and no ansible worker is needed).
#
# - The tasks ahead of the macOS imports in roles/osx/tasks/main.yml are tagged
#   `always`, read the login and groups from the process, refuse another or an
#   administrator account, and set osx_brew_writable false on the offload
#   hosts: a tagged run must still meet the account checks and find it defined.
# - The offload host's own task files never use become.
# - Every Homebrew or App Store task in homebrew.yml and upgrade.yml carries
#   osx_brew_writable, and nothing else does: the planwright updates have to
#   keep running on the offload host, which never writes Homebrew. The includes
#   themselves stay unguarded, for the same reason.
# - The GitHub MCP sync is skipped on the offload host.

set -eu

repo="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"

python3 - "$repo/roles/osx/tasks" <<'PY'
import sys
import yaml

tasks_dir = sys.argv[1]
passed = failed = 0


def ok(msg):
    global passed
    passed += 1
    print(f"  ok: {msg}")


def ko(msg):
    global failed
    failed += 1
    print(f"  FAIL: {msg}")


def load(name):
    with open(f"{tasks_dir}/{name}") as f:
        return yaml.safe_load(f)


def whens(task):
    w = task.get("when", [])
    return [w] if isinstance(w, str) else list(w)


# The exact condition, so a negated guard (`not (osx_brew_writable | bool)`)
# does not pass for one.
def guarded(task):
    return any(w.strip() == "osx_brew_writable | bool" for w in whens(task))


def command_text(task):
    for key in ("ansible.builtin.command", "ansible.builtin.shell"):
        if key in task:
            v = task[key]
            if isinstance(v, str):
                return v
            if "argv" in v:
                return " ".join(str(a) for a in v["argv"])
            return v.get("cmd", "")
    return ""


def writes_homebrew(task):
    if any(k.startswith(("community.general.homebrew", "community.general.mas")) for k in task):
        return True
    cmd = command_text(task).replace("set -o pipefail;", "").strip()
    return cmd.startswith(("brew ", "mas ")) or "Brewfile" in cmd


print("1. guard tasks ahead of the imports run under every tag")
main = load("main.yml")
first_import = next(i for i, t in enumerate(main) if t.get("ansible.builtin.include_tasks") == "osx.yml")
head = main[:first_import]
if not head:
    ko("no guard tasks found ahead of the imports")
for t in head:
    tags = t.get("tags", [])
    if "always" in tags:
        ok(f"{t['name']}: tagged always")
    else:
        ko(f"{t['name']}: tagged {tags}, not always")
# By what each task does, not its name: the two account checks' names share
# their words, so a name match let either stand in for the other.
def arg(task, module, key):
    v = task.get(module)
    return v.get(key) if isinstance(v, dict) else None


def probes(argv, register):
    return any(arg(t, "ansible.builtin.command", "argv") == argv and t.get("register") == register for t in head)


def asserts(that):
    return any(arg(t, "ansible.builtin.assert", "that") == that for t in head)


for label, present in (
    ("the login is read from the process", probes(["id", "-un"], "osx_offload_login")),
    ("the groups are read from the process", probes(["id", "-Gn"], "osx_offload_groups")),
    ("the account check is among them", asserts("osx_offload_login.stdout == osx_offload_user")),
    ("the not-an-administrator check is among them", asserts("'admin' not in osx_offload_groups.stdout.split()")),
):
    ok(label) if present else ko(f"{label}: not found ahead of the imports")
print("1a. an administrator work account is refused after a read-only SSH access check")
names = [t.get("name") for t in head]
refusal = next((i for i, t in enumerate(head) if arg(t, "ansible.builtin.assert", "that") == "'admin' not in osx_offload_groups.stdout.split()"), None)
probe = next((i for i, t in enumerate(head) if "com.apple.access_ssh" in command_text(t)), None)
ok("the SSH access check exists") if probe is not None else ko("no task checks com.apple.access_ssh")
if probe is not None and refusal is not None:
    ok("it runs before the refusal") if probe < refusal else ko("it runs after the refusal")
    ok("it uses no become") if not head[probe].get("become") else ko("it uses become")
    ok("it is read-only") if head[probe].get("changed_when") is False and "dseditgroup -o edit" not in command_text(head[probe]) else ko("it may change the Mac")
    msg = str(head[refusal]["ansible.builtin.assert"].get("fail_msg", ""))
    ok("the refusal names com.apple.access_ssh") if "com.apple.access_ssh" in msg else ko("the refusal does not name com.apple.access_ssh")
    ok("the refusal does not use become") if not head[refusal].get("become") else ko("the refusal uses become")
writable = [arg(t, "ansible.builtin.set_fact", "osx_brew_writable") for t in head if arg(t, "ansible.builtin.set_fact", "osx_brew_writable") is not None]
if writable == ["{{ inventory_hostname not in osx_offload_hosts }}"]:
    ok("osx_brew_writable is false exactly on the offload hosts")
else:
    ko(f"osx_brew_writable is set ahead of the imports as {writable}")

print("1b. the offload host's own tasks never ask for sudo")
for fname in ("offload-host.yml", "offload-tools.yml", "offload-runner.yml", "offload-redis.yml"):
    becomes = [
        sub["name"]
        for t in load(fname)
        for sub in [t] + t.get("block", []) + t.get("rescue", [])
        if sub.get("become")
    ]
    if becomes:
        ko(f"{fname}: {', '.join(becomes)} use become, which the standard work account cannot")
    else:
        ok(f"{fname}: no task uses become")

print("2. Homebrew writes, and only they, carry osx_brew_writable")
for name in ("homebrew.yml", "upgrade.yml"):
    for t in load(name):
        label = f"{name}: {t['name']}"
        if writes_homebrew(t):
            ok(f"{label}: guarded") if guarded(t) else ko(f"{label}: a Homebrew write without the guard")
        else:
            ko(f"{label}: guarded, but writes nothing to Homebrew") if guarded(t) else ok(f"{label}: unguarded")

print("3. the includes stay unguarded")
found = set()
for t in main:
    inc = t.get("ansible.builtin.include_tasks")
    if inc in ("homebrew.yml", "upgrade.yml"):
        found.add(inc)
        ko(f"include {inc}: guarded as a whole") if any("osx_brew_writable" in w for w in whens(t)) else ok(f"include {inc}: unguarded")
for inc in sorted({"homebrew.yml", "upgrade.yml"} - found):
    ko(f"include {inc}: not found as an include_tasks entry in main.yml")

print("4. the GitHub MCP sync never runs on the offload host")
for name in ("homebrew.yml", "upgrade.yml"):
    syncs = [t for t in load(name) if "claude-mcp-sync-github.sh" in command_text(t)]
    if not syncs:
        ko(f"{name}: no GitHub MCP sync task found")
    for t in syncs:
        skips = any(w.strip() == "inventory_hostname not in osx_offload_hosts" for w in whens(t))
        ok(f"{name}: {t['name']}: skipped there") if skips else ko(f"{name}: {t['name']}: runs on the offload host")

print("5. the Redis tasks stay in the work account, private and off Homebrew")
redis = load("offload-redis.yml")
redis_text = open(f"{tasks_dir}/offload-redis.yml").read()
redis_code = "\n".join(l for l in redis_text.splitlines() if not l.lstrip().startswith("#"))
ok("no Homebrew write") if not any(writes_homebrew(t) for t in redis) and "brew" not in redis_code.replace("Homebrew", "") else ko("a Redis task touches brew")
mise_pin = open(f"{tasks_dir}/../files/mise-offload/offload.toml").read()
ok("redis is pinned in offload.toml") if any(l.startswith('redis = "7.') for l in mise_pin.splitlines()) else ko("redis is not pinned to a 7.x release in offload.toml")
conf = open(f"{tasks_dir}/../templates/redis.conf.j2").read().splitlines()
for line in ("bind 127.0.0.1 -::1", "protected-mode yes", "port {{ osx_redis_port }}", 'save ""', "appendonly no", "requirepass {{ osx_redis_password }}"):
    ok(f"redis.conf has `{line}`") if line in conf else ko(f"redis.conf lacks `{line}`")
for t in redis:
    if "ansible.builtin.slurp" in t or "ansible.builtin.template" in t or "ansible.builtin.shell" in t:
        ok(f"{t['name']}: no_log") if t.get("no_log") is True else ko(f"{t['name']}: handles the password without no_log")
gen = next(t for t in redis if "ansible.builtin.shell" in t)
cmd = gen["ansible.builtin.shell"]["cmd"]
ok("the password file is made once, under umask 077") if gen["ansible.builtin.shell"].get("creates") == "{{ osx_redis_passfile }}" and "umask 077" in cmd else ko("the password is not generated once under umask 077")
ok("openssl is called by absolute path, never the owner's Homebrew one") if "&& /usr/bin/openssl rand " in cmd else ko("the password generator does not call /usr/bin/openssl")
modes = {t["ansible.builtin.file"]["path"]: t["ansible.builtin.file"].get("mode") for t in redis if "ansible.builtin.file" in t}
ok("the working directory is 0700") if modes.get("{{ osx_redis_dir }}") == "0700" else ko("the working directory is not 0700")
ok("the password file is kept 0600") if modes.get("{{ osx_redis_passfile }}") == "0600" else ko("the password file is not kept 0600")
rendered = next(t for t in redis if "ansible.builtin.template" in t)["ansible.builtin.template"]
ok("redis.conf is rendered 0600") if rendered.get("mode") == "0600" else ko("redis.conf is not rendered 0600")
cron = [t["ansible.builtin.cron"] for t in redis if "ansible.builtin.cron" in t]
ok("started at boot and re-checked") if any(c.get("special_time") == "reboot" for c in cron) and any(str(c.get("minute", "")).startswith("*/") for c in cron) else ko("no @reboot and periodic cron jobs")
ok("both jobs are the shared start job") if cron and all(c["job"] == "{{ osx_redis_start_job }}" for c in cron) else ko("a cron job is not the Redis start job")
with open(f"{tasks_dir}/../defaults/main.yml") as f:
    job = yaml.safe_load(f)["osx_redis_start_job"]
for needle in ("runner-start.sh", "RUNNER_GATE=", "redis-gate.sh", "RUNNER_PID_PREFIX=dotfiles-redis", "RUNNER_IDLE_SECONDS="):
    ok(f"the job carries {needle}") if needle in job else ko(f"the job lacks {needle}")
ok("the job has no %, which ends a cron command") if "%" not in job else ko("the job holds a %")
ok("the job has no RUNNER_LOAD_MAX: load never stops the server") if "RUNNER_LOAD_MAX" not in job else ko("the job sets RUNNER_LOAD_MAX")

print(f"\nosx-offload-guard: {passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
PY
