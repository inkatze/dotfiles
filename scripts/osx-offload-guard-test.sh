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
writable = [arg(t, "ansible.builtin.set_fact", "osx_brew_writable") for t in head if arg(t, "ansible.builtin.set_fact", "osx_brew_writable") is not None]
if writable == ["{{ inventory_hostname not in osx_offload_hosts }}"]:
    ok("osx_brew_writable is false exactly on the offload hosts")
else:
    ko(f"osx_brew_writable is set ahead of the imports as {writable}")

print("1b. the offload host's own tasks never ask for sudo")
for fname in ("offload-host.yml", "offload-tools.yml", "offload-runner.yml", "offload-postgres.yml"):
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

print("5. postgres runs from the fleet account's mise and crontab, with no Homebrew")
pg = load("offload-postgres.yml")
defaults = load("../defaults/main.yml")
with open(f"{tasks_dir}/../files/mise-offload/offload.toml") as f:
    toml_lines = [l.split("#")[0].strip() for l in f]
ok("offload.toml pins postgres 16") if any(l.startswith('postgres = "16.') for l in toml_lines) else ko("offload.toml does not pin postgres 16")
opts = next((l for l in toml_lines if l.startswith("POSTGRES_CONFIGURE_OPTIONS")), "")
if all(w in opts for w in ("--without-icu", "--without-readline", "--without-openssl")):
    ok("the build drops the libraries the owner's Homebrew would supply")
else:
    ko("offload.toml does not drop icu, readline and openssl from the postgres build")
ok("postgres is among the mise tools installed") if "postgres" in defaults["osx_offload_mise_tools"] else ko("postgres is not in osx_offload_mise_tools")
initdb = [t for t in pg if "initdb" in command_text(t)]
if initdb and all(arg(t, "ansible.builtin.command", "creates") == "{{ osx_postgres_data }}/PG_VERSION" for t in initdb):
    ok("initdb runs only when the data directory is absent")
else:
    ko("initdb is missing or not guarded by creates on PG_VERSION")
args = [str(a) for t in initdb for a in arg(t, "ansible.builtin.command", "argv")]
for want in ("--auth-local=peer", "--auth-host=scram-sha-256"):
    ok(f"initdb passes {want}") if want in args else ko(f"initdb lacks {want}")
ko("initdb allows trust") if any("trust" in a for a in args) else ok("initdb allows no trust login")
socket = [t for t in pg if arg(t, "ansible.builtin.file", "path") == "{{ osx_postgres_socket_dir }}"]
if socket and all(arg(t, "ansible.builtin.file", "mode") == "0700" for t in socket):
    ok("the socket directory is mode 0700")
else:
    ko("the socket directory is not created with mode 0700")
pgpass = [t for t in pg if arg(t, "ansible.builtin.lineinfile", "path") == "{{ osx_postgres_pgpass }}"]
if pgpass and all(arg(t, "ansible.builtin.lineinfile", "mode") == "0600" and t.get("no_log") for t in pgpass):
    ok("the password lands in a 0600 file, from a no_log task")
else:
    ko("the .pgpass line is not written 0600 from a no_log task")
if pgpass and all(whens(t) and "regex_search" in whens(t)[0] for t in pgpass):
    ok("an existing .pgpass line is kept: the write runs only when it is absent")
else:
    ko("the .pgpass write is not conditional on the line being absent")
cron = [t["ansible.builtin.cron"] for t in pg if "ansible.builtin.cron" in t]
ok("an @reboot job") if any(c.get("special_time") == "reboot" for c in cron) else ko("no @reboot cron job")
ok("a periodic re-check job") if any(str(c.get("minute", "")).startswith("*/") for c in cron) else ko("no periodic re-check cron job")
for c in cron:
    ok(f"{c['name']}: the shared start job") if c["job"] == "{{ osx_postgres_start_job }}" else ko(f"{c['name']}: job is not the shared start job")
job = defaults["osx_postgres_start_job"]
for needle in ("PATH=", "RUNNER_IDLE_SECONDS=", "RUNNER_LOAD_MAX=", "RUNNER_NICE=", "RUNNER_GATE=", "RUNNER_PID_PREFIX=", "POSTGRES_SOCKET_DIR=", "POSTGRES_MAX_CONNECTIONS=", "runner-start.sh"):
    ok(f"start job carries {needle}") if needle in job else ko(f"start job lacks {needle}")
ok("start job holds no %") if "%" not in job else ko("start job holds a % (it ends a cron command)")
ok("start job carries no password") if "PASSWORD" not in job.upper() else ko("start job names a password")
code = open(f"{tasks_dir}/offload-postgres.yml").read()
code = "\n".join(l for l in code.splitlines() if not l.lstrip().startswith("#"))
for word in ("launchctl", "LaunchAgents", "brew", "become"):
    ko(f"offload-postgres.yml mentions {word}") if word in code else ok(f"offload-postgres.yml never mentions {word}")

print(f"\nosx-offload-guard: {passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
PY
