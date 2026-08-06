#!/usr/bin/env bash
# Test for the `services` role's declared dev-services layer (specs/dev-services
# Task 2, D-1 and D-5). Makes Task 2's Done-when checkable rather than reviewed:
#
# Grouped rather than enumerated, so adding a case does not silently leave a
# numbered list here describing a different test than the one below. Each case
# prints its own `ok[name]` line; that output is the authoritative inventory.
#
#   Declaration  -- the list is non-empty (REQ-B1.1), every entry carries
#                   package, unit, listen address and listen port (REQ-B1.2),
#                   and every declared address is loopback (REQ-A1.3).
#   Lifecycle    -- every task is driven from the declaration and none names a
#                   service, so adding one is a declaration edit rather than a
#                   control-flow edit; all four steps (install, enable, start,
#                   verify) are present; both platform files are reachable
#                   from the role's entry point (REQ-B1.1).
#   Guards       -- the Linux lifecycle provisions nothing on a macOS host, and
#                   the role's macOS-only content, `~/.my.cnf` included, runs
#                   on no Linux host (REQ-B1.4).
#   Tags         -- `-t services` and `-t colima` each select the tasks they
#                   name, since a tag selecting nothing is a role that exits 0
#                   having done nothing at all.
#   CI matrix    -- a `services` entry runs at strict idempotency, which is
#                   what makes the guards executable rather than reviewed
#                   (REQ-B1.4), and this branch modifies no pre-existing entry
#                   and no shared step definition (REQ-E1.4).
#
# The guard cases are behavioural: they run the role's task files under a
# stubbed `os_family` and assert nothing executed. That is the same guard the
# macOS matrix entry exercises on a real runner, run here in a second and
# without one. The reverse direction -- that the lifecycle does provision on
# Linux -- needs a real Linux runner and belongs to Task 6's job.
#
# Not wired into CI/lefthook (CI runs the role itself, which is the stronger
# signal); run manually: `scripts/services-declaration-test.sh`.
# Exit 0 = all assertions pass.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
role="$repo_root/roles/services"
defaults="$role/defaults/main.yml"
tasks_dir="$role/tasks"
workflow="$repo_root/.github/workflows/test.yml"

fails=0
pass() { echo "ok[$1]: $2"; }
fail() {
    echo "FAIL[$1]: $2" >&2
    fails=$((fails + 1))
}

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo "FAIL: ansible-playbook not on PATH; the guard cases below need it" >&2
    exit 1
fi

if ! python3 -c 'import yaml' 2>/dev/null; then
    echo "FAIL: PyYAML is unavailable; it ships with ansible's dependencies" >&2
    exit 1
fi

# Ansible refuses to start at all under a non-UTF-8 locale, and says so in
# terms of the locale rather than of the role, which reads like this test is
# broken. Normalise once here rather than letting each behavioural case below
# fail that way.
case "${LC_ALL:-${LANG:-}}" in
*UTF-8* | *utf8*) ;;
*) export LC_ALL=C.UTF-8 LANG=C.UTF-8 ;;
esac

# ---------------------------------------------------------------------------
# Declaration and lifecycle: structural assertions over the declared list
# and the role's task files.
# ---------------------------------------------------------------------------

structural_rc=0
python3 - "$defaults" "$tasks_dir" <<'PY' || structural_rc=$?
import pathlib
import sys

import yaml

defaults_path, tasks_dir = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
failed = []


def ok(name, msg):
    print(f"ok[{name}]: {msg}")


def bad(name, msg):
    print(f"FAIL[{name}]: {msg}", file=sys.stderr)
    failed.append(name)


# declaration-exists (REQ-B1.1) -- the list exists, parses, and is not empty.
if not defaults_path.is_file():
    bad("declaration-exists", f"{defaults_path} does not exist")
    sys.exit(1)

declared = (yaml.safe_load(defaults_path.read_text()) or {}).get("services_dev_services")
if not isinstance(declared, list) or not declared:
    bad("declaration-exists", "services_dev_services is missing, empty, or not a list")
    sys.exit(1)
ok("declaration-exists", f"{len(declared)} service(s) declared")

# declaration-fields (REQ-B1.2) -- every entry carries the fields the
# requirement names.
required = ("name", "package", "unit", "listen_address", "listen_port")
missing = {
    entry.get("name", f"#{i}"): [f for f in required if not entry.get(f)]
    for i, entry in enumerate(declared)
    if [f for f in required if not entry.get(f)]
}
if missing:
    bad("declaration-fields", f"entries missing required fields: {missing}")
elif not all(isinstance(e["listen_port"], int) for e in declared):
    bad("declaration-fields", "listen_port must be an integer, not a string")
else:
    ok("declaration-fields", f"every entry carries {', '.join(required)}")

# declaration-loopback (REQ-A1.3) -- a declared service is expected on
# loopback, never on a
# routable interface. The declaration is what the verify step asserts against,
# so a wrong address here would certify the wrong thing.
loopback = {"127.0.0.1", "::1", "localhost"}
offenders = [e["name"] for e in declared if e.get("listen_address") not in loopback]
if offenders:
    bad("declaration-loopback", f"non-loopback listen_address declared for: {offenders}")
else:
    ok("declaration-loopback", "every declared listen address is loopback")

# The lifecycle cases below all read the Linux lifecycle file.
linux_path = tasks_dir / "linux.yml"
if not linux_path.is_file():
    bad("lifecycle-file", f"{linux_path} does not exist")
    sys.exit(1)

linux_doc = yaml.safe_load(linux_path.read_text()) or []
lifecycle = [t for top in linux_doc for t in (top.get("block") or [top])]
if not lifecycle:
    bad("lifecycle-file", "no lifecycle tasks found")
    sys.exit(1)

# lifecycle-declaration-driven (REQ-B1.1) -- every lifecycle task reads the
# declaration. A task that does
# not is one the declaration cannot drive.
undriven = [
    t.get("name", "<unnamed>")
    for t in lifecycle
    if "services_dev_services" not in yaml.safe_dump(t)
]
if undriven:
    bad("lifecycle-declaration-driven", f"tasks not driven from the declaration: {undriven}")
else:
    ok("lifecycle-declaration-driven", f"all {len(lifecycle)} lifecycle task(s) read the declaration")

# no-per-service-branching (REQ-B1.1) -- "adding a service requires no task
# edit" is exactly the
# property that no task file names a service. Checked against every declared
# identifier, in every task file, so a per-service branch cannot hide in one.
# Against the parsed document rather than the raw text: the requirement is
# about control flow, and a comment naming a service is prose, not a branch.
named = []
for task_file in sorted(tasks_dir.glob("*.yml")):
    body = yaml.safe_dump(yaml.safe_load(task_file.read_text()) or [])
    for entry in declared:
        for field in ("name", "package", "unit"):
            token = str(entry[field])
            if token in body:
                named.append(f"{task_file.name} names '{token}'")
if named:
    bad("no-per-service-branching", f"task files name declared services: {named}")
else:
    ok("no-per-service-branching", "no task file names any declared service")

# lifecycle-steps-present (REQ-B1.1) -- all four steps are present. Asserted
# by the module
# each step must use, since a step's absence is otherwise invisible: a role
# that installs and starts but never verifies still converges green.
modules = {k for t in lifecycle for k in t if k.startswith("ansible.builtin.")}
steps = {
    "install": "ansible.builtin.apt" in modules,
    "enable+start": any(
        t.get("ansible.builtin.systemd_service", {}).get("enabled") is not None
        and t.get("ansible.builtin.systemd_service", {}).get("state") is not None
        for t in lifecycle
        if "ansible.builtin.systemd_service" in t
    ),
    "verify": "ansible.builtin.wait_for" in modules,
}
absent = [step for step, present in steps.items() if not present]
if absent:
    bad("lifecycle-steps-present", f"lifecycle steps absent: {absent}")
else:
    ok("lifecycle-steps-present", "install, enable, start and verify all present")

# platform-files-imported -- both platform files have to be reachable from
# the role's entry point.
# The behavioural cases below import each leaf file directly, which is what
# makes them isolated -- and is also why they cannot notice an import being
# dropped from main.yml. Nothing else would: a role that silently stopped
# applying its macOS content would just report changed=0 and pass the CI
# matrix entry's idempotency check.
main_doc = yaml.safe_dump(yaml.safe_load((tasks_dir / "main.yml").read_text()) or [])
unreachable = [
    leaf for leaf in ("linux.yml", "darwin.yml") if leaf not in main_doc
]
if unreachable:
    bad("platform-files-imported", f"main.yml does not import: {unreachable}")
else:
    ok("platform-files-imported", "main.yml imports both platform files")

sys.exit(1 if failed else 0)
PY

if [[ "$structural_rc" -ne 0 ]]; then
    fails=$((fails + 1))
fi

# ---------------------------------------------------------------------------
# Guards (REQ-B1.4), behavioural. Each direction imports one platform's task file
# under the other platform's `os_family` and asserts the play executed nothing:
# `ok=0 changed=0 failed=0` with a non-zero skip count. A missing guard shows
# up as an executed or failed task, never as a pass.
# ---------------------------------------------------------------------------

# assert_all_skipped <name> <task-file> <stubbed-os_family> <what>
assert_all_skipped() {
    local name="$1" task_file="$2" os_family="$3" what="$4"
    local play="$workdir/$name.yml" out="$workdir/$name.out"

    cat >"$play" <<EOF
---
- name: $name
  hosts: localhost
  gather_facts: false
  connection: local
  vars:
    ansible_facts:
      os_family: $os_family
  vars_files:
    - $defaults
  tasks:
    - name: Import the guarded task file under test
      ansible.builtin.import_tasks: $task_file
EOF

    if ! ansible-playbook -i localhost, "$play" >"$out" 2>&1; then
        fail "$name" "the play did not complete; $what may be unguarded (see below)
$(sed 's/^/    /' "$out")"
        return
    fi

    local recap
    recap=$(grep -o 'ok=[0-9]*  *changed=[0-9]*.*' "$out" | tail -1)
    if [[ -z "$recap" ]]; then
        fail "$name" "no PLAY RECAP in ansible output"
        return
    fi
    if ! grep -qE 'ok=0 +changed=0' <<<"$recap"; then
        fail "$name" "$what executed on a $os_family host: $recap"
        return
    fi
    if grep -qE 'skipped=0' <<<"$recap"; then
        fail "$name" "nothing was skipped, so no guard was exercised: $recap"
        return
    fi
    pass "$name" "$what provisioned nothing on $os_family ($recap)"
}

assert_all_skipped "linux-lifecycle-skips-on-macos" "$tasks_dir/linux.yml" \
    "Darwin" "the declared-service lifecycle"

assert_all_skipped "macos-content-skips-on-linux" "$tasks_dir/darwin.yml" \
    "Debian" "the role's macOS-only content"

# The guard above is only worth having if it covers the task that motivated it:
# the `~/.my.cnf` symlink carried no `when:` at all and so ran on the Linux
# host. Named explicitly because Task 7 asserts this exact file's absence on
# the host, and because a recap-wide `ok=0` would still pass if this task were
# dropped from the role rather than guarded. Asserted as "the task ran and
# reported skipping", not merely "the name appears".
mycnf_out="$workdir/macos-content-skips-on-linux.out"
if ! grep -q 'my\.cnf' "$tasks_dir/darwin.yml" 2>/dev/null; then
    fail "my-cnf-guarded" "no ~/.my.cnf task in darwin.yml; Task 7 asserts this file's absence"
elif [[ ! -s "$mycnf_out" ]] ||
    ! grep -A1 'TASK \[Symlink my\.cnf\]' "$mycnf_out" | grep -q '^skipping:'; then
    fail "my-cnf-guarded" "the ~/.my.cnf task did not report skipping on a Debian host"
else
    pass "my-cnf-guarded" "the ~/.my.cnf task was reached and skipped on Debian"
fi

# ---------------------------------------------------------------------------
# The role's tags must actually select its tasks. `mise run services` is
# `playbook.sh -t services`, so a tag that selects nothing is a role that
# silently does nothing while exiting 0 -- no failure, no output, no service.
# The live hazard is roles/services/tasks/main.yml's import_tasks: this repo
# mostly uses include_tasks, which is opaque to the tag selector, and swapping
# to it here drops both selections to zero. Asserted rather than commented so
# tidying that file toward the majority idiom fails here instead of on a host.
# ---------------------------------------------------------------------------

# assert_tag_selects <name> <tag> <grep-pattern> <what>
assert_tag_selects() {
    local name="$1" tag="$2" pattern="$3" what="$4" count
    count=$( (cd "$repo_root" && ansible-playbook main.yml --list-tasks -t "$tag" 2>/dev/null) |
        grep -c "$pattern" || true)
    if [[ "$count" -eq 0 ]]; then
        fail "$name" "\`-t $tag\` selected no $what; the role would run silently empty"
    else
        pass "$name" "\`-t $tag\` selects $count $what"
    fi
}

assert_tag_selects "services-tag-selects" "services" '^ *services :' "task(s) in the role"
assert_tag_selects "colima-tag-selects" "colima" 'TAGS: \[colima' "colima task(s)"

# ---------------------------------------------------------------------------
# CI matrix. The entry is what turns the guards from a review into a run, and
# REQ-E1.4 is the constraint that buying it must cost no pre-existing coverage.
# ---------------------------------------------------------------------------

matrix_rc=0
python3 - "$workflow" <<'PY' || matrix_rc=$?
import pathlib
import sys

import yaml

doc = yaml.safe_load(pathlib.Path(sys.argv[1]).read_text())
entries = doc["jobs"]["test"]["strategy"]["matrix"]["include"]
services = [e for e in entries if e.get("role") == "services"]

if not services:
    print("FAIL[matrix-entry]: no `services` entry in the macOS test matrix", file=sys.stderr)
    sys.exit(1)
if not all(e.get("strict_idempotency") is True for e in services):
    print(
        "FAIL[matrix-entry]: the `services` entry must run at strict_idempotency: true",
        file=sys.stderr,
    )
    sys.exit(1)
print("ok[matrix-entry]: `services` runs in the macOS matrix at strict idempotency")
PY
if [[ "$matrix_rc" -ne 0 ]]; then
    fails=$((fails + 1))
fi

# REQ-E1.4 -- stated as a rule, so checked as one: this branch's diff against
# the base may add lines to the workflow and remove none. A removal is either a
# modified pre-existing entry or a modified shared step, and the requirement
# admits neither.
base=$(git -C "$repo_root" merge-base HEAD origin/main 2>/dev/null || true)
if [[ -z "$base" ]]; then
    echo "skip[matrix-preexisting-unmodified]: no origin/main to diff against;" \
        "REQ-E1.4 is not exercised on this checkout"
else
    removed=$(git -C "$repo_root" diff "$base" -- .github/workflows/ |
        grep -c '^-[^-]' || true)
    if [[ "$removed" -ne 0 ]]; then
        fail "matrix-preexisting-unmodified" \
            "$removed workflow line(s) removed or changed; REQ-E1.4 permits additions only"
    else
        pass "matrix-preexisting-unmodified" "workflow diff is additions only"
    fi
fi

if [[ "$fails" -ne 0 ]]; then
    echo "services-declaration-test: $fails assertion group(s) failed" >&2
    exit 1
fi
echo "services-declaration-test: all assertions passed"
