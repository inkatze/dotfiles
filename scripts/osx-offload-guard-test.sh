#!/usr/bin/env bash
# Static checks on the osx role's offload-host guards, read from the task files
# with PyYAML (no play runs, so no Mac and no ansible worker is needed).
#
# 1. Every task ahead of the macOS imports in roles/osx/tasks/main.yml is
#    tagged `always`: a tagged run must still meet the account check, and must
#    find osx_brew_writable defined.
# 2. Every Homebrew or App Store write in homebrew.yml and upgrade.yml carries
#    osx_brew_writable, and nothing else does: the MCP sync and the planwright
#    updates have to keep running when another account owns the prefix.
# 3. The includes themselves stay unguarded, for the same reason.

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


def guarded(task):
    return any("osx_brew_writable" in w for w in whens(task))


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
names = [t["name"] for t in head]
if any("Refuse" in n and "account" in n for n in names):
    ok("the account check is among them")
else:
    ko("the account check is not ahead of the imports")
if any("administrator" in n for n in names):
    ok("the not-an-administrator check is among them")
else:
    ko("the not-an-administrator check is not ahead of the imports")

print("1b. the offload host's own tasks never ask for sudo")
for fname in ("offload-host.yml", "offload-tools.yml"):
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
for t in main:
    inc = t.get("ansible.builtin.include_tasks")
    if inc in ("homebrew.yml", "upgrade.yml"):
        ko(f"include {inc}: guarded as a whole") if guarded(t) else ok(f"include {inc}: unguarded")

print(f"\nosx-offload-guard: {passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
PY
