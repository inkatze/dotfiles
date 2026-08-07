#!/usr/bin/env bash
# Test for the `services` role's declared dev-services layer (specs/dev-services
# Tasks 2 and 3, D-1, D-4, D-5 and D-6). Makes their Done-when checkable rather
# than reviewed:
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
#   Bespoke setup -- a service needing more than the shared lifecycle names
#                   where that setup lives, in its declaration entry, and is
#                   reached only through that field (REQ-B1.3); the setup uses
#                   `ansible.builtin` and nothing else (D-6) and is written so
#                   a second run has a reason to do less than the first
#                   (REQ-C1.1).
#   PostgreSQL   -- the distribution's own configuration is left alone: no
#                   task, template or file in this repo manages `pg_hba.conf`,
#                   `postgresql.conf` or `listen_addresses` (D-4, Task 3
#                   Done-when). The access harness is present, and refuses
#                   visibly rather than passing vacuously when it cannot
#                   actually prove anything (REQ-A1.4).
#
# The guard cases are behavioural: they run the role's task files under a
# stubbed `os_family` and assert nothing executed. That is the same guard the
# macOS matrix entry exercises on a real runner, run here in a second and
# without one. The reverse direction -- that the lifecycle does provision on
# Linux -- needs a real Linux runner and belongs to Task 6's job.
#
# Everything here is structural or stubbed, deliberately: it runs on a laptop
# with no PostgreSQL installed and no root. Proving that a client can actually
# connect needs a provisioned server, which is what
# scripts/postgresql-access-test.sh is for -- Task 6 runs it in CI and Task 7
# runs it on the host. The two are complements, and neither substitutes for
# the other: this file proves the role is written correctly, that one proves
# the result works.
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

# bespoke-setup-declared (REQ-B1.3, D-5) -- a service whose setup exceeds the
# shared lifecycle names, in its own entry, the file that setup lives in, so
# the full picture for that service is reachable from the declaration alone.
#
# The value must be a bare filename resolved against the role's tasks/
# directory. A separator or a parent reference would let declaration data
# decide which file the role executes from outside the role, which is a
# different and much larger thing than naming one of its own task files.
#
# Asserting that at least one exists is deliberate rather than incidental:
# PostgreSQL is that service in this bundle (its database role is bespoke by
# D-4 and D-6), so an empty set means the dispatch has been removed. A future
# bundle that genuinely has no bespoke setup left will have to edit this line,
# which is the visible conversation that deletion deserves.
setup_files = {}
bad_refs = []
for entry in declared:
    ref = entry.get("setup")
    if ref is None:
        continue
    if not isinstance(ref, str) or "/" in ref or ref.startswith("."):
        bad_refs.append(f"{entry['name']}: {ref!r} is not a bare filename")
    elif not (tasks_dir / ref).is_file():
        bad_refs.append(f"{entry['name']}: {ref} is not a file in {tasks_dir}")
    else:
        setup_files[ref] = entry["name"]
if bad_refs:
    bad("bespoke-setup-declared", f"unusable setup reference(s): {bad_refs}")
elif not setup_files:
    bad("bespoke-setup-declared", "no declared service names a bespoke setup file")
else:
    ok("bespoke-setup-declared", f"bespoke setup declared for: {sorted(setup_files.values())}")

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
#
# Bespoke setup files are exempt, and the exemption is derived rather than
# hardcoded: it is exactly the set of files the declaration's `setup:` fields
# name. A file that exists to configure one service names that service --
# that is what "bespoke" means, and REQ-B1.3 blesses it explicitly, while
# REQ-B1.1's no-branching property is about the *shared* lifecycle. The
# exemption costs nothing because `bespoke-setup-dispatch` below asserts the
# only route into those files is the declaration itself: reaching one still
# takes a declaration entry rather than a task edit, which is the whole of
# what REQ-B1.1 asks.
named = []
for task_file in sorted(tasks_dir.glob("*.yml")):
    if task_file.name in setup_files:
        continue
    body = yaml.safe_dump(yaml.safe_load(task_file.read_text()) or [])
    for entry in declared:
        for field in ("name", "package", "unit"):
            token = str(entry[field])
            if token in body:
                named.append(f"{task_file.name} names '{token}'")
if named:
    bad("no-per-service-branching", f"task files name declared services: {named}")
else:
    ok("no-per-service-branching", "no shared task file names any declared service")

# bespoke-setup-dispatch (REQ-B1.1, REQ-B1.3) -- what makes the exemption
# above safe. Asserted in both directions: some lifecycle task includes
# `item.setup` while looping over the declaration, and no task file reaches a
# setup file by writing its name. Together those say the declaration is the
# only door in, so a per-service branch cannot hide behind one.
dispatch = [
    t
    for t in lifecycle
    if "item.setup" in str(t.get("ansible.builtin.include_tasks", ""))
]
hardcoded = [
    f"{p.name} names '{ref}'"
    for p in sorted(tasks_dir.glob("*.yml"))
    for ref in setup_files
    if ref in yaml.safe_dump(yaml.safe_load(p.read_text()) or [])
]
if not dispatch:
    bad("bespoke-setup-dispatch", "no lifecycle task includes item.setup")
elif not all("services_dev_services" in yaml.safe_dump(t) for t in dispatch):
    bad("bespoke-setup-dispatch", "the setup dispatch does not loop over the declaration")
elif hardcoded:
    bad("bespoke-setup-dispatch", f"setup file(s) reached by literal name: {hardcoded}")
else:
    ok("bespoke-setup-dispatch", "bespoke setup is reached only through the declaration")

# The two cases below read every declared setup file's tasks, flattened out of
# any enclosing block the same way the lifecycle is above.
setup_tasks = {
    ref: [
        t
        for top in (yaml.safe_load((tasks_dir / ref).read_text()) or [])
        for t in (top.get("block") or [top])
    ]
    for ref in sorted(setup_files)
}

# bespoke-setup-builtin-only (D-6) -- the bespoke setup uses `ansible.builtin`
# and nothing else. This is exactly where `community.postgresql` would first be
# reached for: `postgresql_user` is one line where a guarded query is three,
# and the pull is real. D-6 declined the collection for reasons that outlive
# the convenience -- a bootstrap step on the host, a matching install step in
# CI, and a dependency surface this repo has so far had none of.
#
# Asserted rather than reviewed because the drift is invisible on exactly the
# machine most likely to introduce it. D-6 records that `ansible` on the target
# host resolves to a batteries-included distribution carrying the collection
# already, so a task using it works there and fails wherever the repo's
# declared `ansible-core` is what runs.
noncore = [
    f"{ref}: {key}"
    for ref, tasks in setup_tasks.items()
    for t in tasks
    for key in t
    if "." in key and not key.startswith("ansible.builtin.")
]
if noncore:
    bad("bespoke-setup-builtin-only", f"non-builtin module(s) in bespoke setup: {noncore}")
else:
    ok("bespoke-setup-builtin-only", "every bespoke setup task uses ansible.builtin")

# bespoke-setup-idempotent (REQ-C1.1) -- bespoke setup is where convergence is
# easiest to lose. The shared lifecycle is all module calls that decide for
# themselves whether they changed anything; a bespoke file is where `command`
# appears, and `command` reports changed on every run unless something says
# otherwise. Every task must therefore either declare it changes nothing, or
# be guarded, so that a second run has a reason to do less than the first.
#
# Structural rather than behavioural, and honest about it: proving convergence
# takes two real runs against a real server, which is the CI job's idempotency
# re-run in Task 6. What this catches is the unguarded `command` that would
# fail that job, at the point it is written rather than a task later.
unguarded = [
    f"{ref}: {t.get('name', '<unnamed>')}"
    for ref, tasks in setup_tasks.items()
    for t in tasks
    if t.get("changed_when") is not False and "when" not in t
]
if unguarded:
    bad("bespoke-setup-idempotent", f"task(s) neither guarded nor changed_when: false: {unguarded}")
else:
    ok("bespoke-setup-idempotent", "every bespoke setup task is guarded or declares no change")

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
# The bespoke-setup dispatch, behaviourally (REQ-B1.1, REQ-B1.3). The
# structural cases above assert the dispatch is *written* to read the
# declaration; this one runs it and watches where it goes, against a stubbed
# declaration so no server is needed.
#
# Two directions, and the second is the one worth the setup cost. A service
# declaring `setup:` must reach that file; a service declaring none must
# contribute no task at all rather than an error about an undefined key. The
# declaration holds one of each today -- PostgreSQL has bespoke setup and
# Valkey does not -- so a dispatch that mishandled the second would break a
# service whose own task never changed.
#
# Run under `-t services`, the tag `mise run services` passes, because a
# dynamic include is where tag selection silently stops reaching tasks. That
# is the failure main.yml's note describes and the one no recap distinguishes
# from a role with nothing to do.
#
# The dispatch task is lifted out of linux.yml rather than rewritten here: a
# hand-copied lookalike would keep passing after the real one changed, which
# is the only way this case could mislead.
# ---------------------------------------------------------------------------

dispatch_rc=0
python3 - "$tasks_dir" "$workdir" <<'PY' || dispatch_rc=$?
import pathlib
import sys

import yaml

tasks_dir, workdir = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
doc = yaml.safe_load((tasks_dir / "linux.yml").read_text()) or []
tasks = [t for top in doc for t in (top.get("block") or [top])]
dispatch = [
    t for t in tasks if "item.setup" in str(t.get("ansible.builtin.include_tasks", ""))
]
if len(dispatch) != 1:
    print(
        f"FAIL[bespoke-setup-runs]: expected one dispatch task in linux.yml, found {len(dispatch)}",
        file=sys.stderr,
    )
    sys.exit(1)

outer = doc[0]
(workdir / "dispatch.yml").write_text(
    yaml.safe_dump(
        [{"name": outer["name"], "when": outer["when"], "tags": outer["tags"], "block": dispatch}]
    )
)
(workdir / "stub-setup.yml").write_text(
    yaml.safe_dump(
        [{"name": "Stubbed bespoke setup", "ansible.builtin.debug": {"msg": "STUB-SETUP-RAN"}}]
    )
)
(workdir / "dispatch-play.yml").write_text(
    yaml.safe_dump(
        [
            {
                "name": "bespoke setup dispatch",
                "hosts": "localhost",
                "gather_facts": False,
                "connection": "local",
                "vars": {
                    "ansible_facts": {"os_family": "Debian"},
                    "services_dev_services": [
                        {"name": "Declares bespoke setup", "setup": str(workdir / "stub-setup.yml")},
                        {"name": "Declares none"},
                    ],
                },
                "tasks": [
                    {
                        "name": "The dispatch task, as linux.yml writes it",
                        "ansible.builtin.import_tasks": str(workdir / "dispatch.yml"),
                    }
                ],
            }
        ]
    )
)
PY

if [[ "$dispatch_rc" -ne 0 ]]; then
    fails=$((fails + 1))
else
    dispatch_out="$workdir/dispatch.out"
    if ! ansible-playbook -i localhost, -t services "$workdir/dispatch-play.yml" \
        >"$dispatch_out" 2>&1; then
        fail "bespoke-setup-runs" "the dispatch play did not complete:
$(sed 's/^/    /' "$dispatch_out")"
    elif ! grep -q 'STUB-SETUP-RAN' "$dispatch_out"; then
        fail "bespoke-setup-runs" \
            "\`-t services\` did not reach the declared setup file; the include is selected
    but its tasks are not, which is the silent failure main.yml's note describes"
    else
        # ok=2 is the include plus the one stubbed task it pulled in. A third
        # would mean the entry declaring no setup produced something; a
        # failure would mean it produced an error about a missing key.
        recap=$(grep -o 'ok=[0-9]*  *changed=[0-9]*.*' "$dispatch_out" | tail -1)
        if ! grep -qE 'ok=2 .*failed=0' <<<"$recap"; then
            fail "bespoke-setup-runs" \
                "a service declaring no bespoke setup did not contribute zero tasks: $recap"
        else
            pass "bespoke-setup-runs" \
                "\`-t services\` reached the declared setup and skipped the service without one"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# PostgreSQL's own configuration stays the distribution's (D-4, Task 3's
# Done-when). D-4 chose peer authentication over the Unix socket precisely
# because it needs no deviation from the shipped configuration -- there is
# nothing to template, converge, or keep correct across a major upgrade. The
# checkable form of that intent is not a diff against a packaged default,
# because the distribution generates `pg_hba.conf` at cluster creation rather
# than shipping it as a conffile; it is that nothing in this repo touches the
# file at all.
#
# Scoped to `roles/` and the playbook, which is where every task, template and
# file in this repo lives. `listen_addresses` is in the pattern alongside the
# two filenames because it is the specific setting that would widen the bind
# past loopback (REQ-A1.3), and it would arrive by way of managing
# `postgresql.conf`.
# ---------------------------------------------------------------------------

# `--others --exclude-standard` alongside the tracked listing, and not
# incidentally: a bare `git ls-files` sees committed files only, so a new task
# file managing the config would pass this assertion right up until it was
# committed -- including, when this case was written, the very file Task 3 was
# adding. Untracked-but-not-ignored is the honest scope for "nothing in this
# repo does this", since that is what is about to become a commit.
(cd "$repo_root" && git ls-files --cached --others --exclude-standard -- roles/ main.yml) \
    >"$workdir/pg-listing.txt"

pg_rc=0
python3 - "$repo_root" "$workdir/pg-listing.txt" <<'PY' || pg_rc=$?
import pathlib
import re
import sys

import yaml

root, listing = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
pattern = re.compile(r"pg_hba|postgresql\.conf|listen_addresses")
hits = []

# splitlines(), not split(): git prints one path per line, and a path
# containing a space would otherwise arrive as two nonexistent ones -- both of
# which fail the is_file() check below and vanish from the scan silently. No
# such path is tracked today, which is exactly why this would go unnoticed.
for rel in filter(None, listing.read_text().splitlines()):
    path = root / rel
    # A file *named* for the configuration is one shipped to be copied into
    # place, which is managing it in the most direct way there is.
    if pattern.search(rel):
        hits.append(f"{rel} -- shipped as a configuration file")
        continue
    if not path.is_file():
        continue
    try:
        text = path.read_text()
    except (OSError, UnicodeDecodeError):
        continue
    # Against the parsed document for YAML, the raw text otherwise -- the same
    # split `no-per-service-branching` above makes, for the same reason. The
    # requirement is that nothing *manages* these files; a comment explaining
    # which files are deliberately left alone is prose, and roles/services'
    # own setup file is the first thing that would trip a raw grep. An
    # unparseable YAML file falls back to raw text, which over-reports rather
    # than waving the file through.
    if path.suffix in (".yml", ".yaml"):
        try:
            text = yaml.safe_dump(yaml.safe_load(text) or [])
        except yaml.YAMLError:
            pass
    if pattern.search(text):
        hits.append(f"{rel} -- names it in a task")

if hits:
    print(
        "FAIL[pg-config-unmanaged]: PostgreSQL configuration is managed by:\n"
        + "\n".join(f"    {h}" for h in sorted(hits)),
        file=sys.stderr,
    )
    sys.exit(1)
print("ok[pg-config-unmanaged]: no task, template or file manages PostgreSQL's configuration")
PY
if [[ "$pg_rc" -ne 0 ]]; then
    fails=$((fails + 1))
fi

# ---------------------------------------------------------------------------
# The access harness (REQ-A1.4). Proving a client can connect needs a
# provisioned server, so the harness itself lives in a separate script that
# Task 6 runs in CI and Task 7 runs on the host. What is checkable from here
# is the property that makes it worth running at all: that it refuses visibly
# instead of passing vacuously.
#
# That is not a hypothetical failure mode. A verification script whose
# preconditions are absent has two ways to behave, and the difference is
# invisible in a green log: exit 0 having proved nothing, or exit non-zero
# naming what was missing. The first is worse than having no test, because it
# reports coverage that does not exist -- the same reasoning REQ-D1.4 applies
# to the identifier generator in Task 1.
# ---------------------------------------------------------------------------

access_test="$repo_root/scripts/postgresql-access-test.sh"
if [[ ! -x "$access_test" ]]; then
    fail "access-harness-present" "$access_test is missing or not executable"
else
    pass "access-harness-present" "the access harness is present and executable"

    # A supplied password is what REQ-A1.4's fixture must not contain: with one
    # present, a passing run proves the server accepts that password, not that
    # it needs none. Checked before anything else in the harness, so this case
    # runs on a host with no PostgreSQL at all.
    fixture_out="$workdir/access-fixture.out"
    if PGPASSWORD=never-used "$access_test" >"$fixture_out" 2>&1; then
        fail "access-harness-fixture" \
            "the harness passed with PGPASSWORD set; it cannot prove a passwordless connection"
    elif ! grep -qi 'PGPASSWORD' "$fixture_out"; then
        fail "access-harness-fixture" \
            "the harness refused without naming the compromised fixture:
$(sed 's/^/    /' "$fixture_out")"
    else
        pass "access-harness-fixture" "the harness refuses when a password is available to it"
    fi

    if command -v psql >/dev/null 2>&1; then
        echo "skip[access-harness-refuses]: psql is installed, so the no-server refusal" \
            "cannot be exercised here; run scripts/postgresql-access-test.sh directly"
    else
        refusal_out="$workdir/access-refusal.out"
        if "$access_test" >"$refusal_out" 2>&1; then
            fail "access-harness-refuses" \
                "the harness exited 0 with no PostgreSQL client present; it proved nothing"
        elif ! grep -qi 'psql' "$refusal_out"; then
            fail "access-harness-refuses" \
                "the harness refused without naming the missing client:
$(sed 's/^/    /' "$refusal_out")"
        else
            pass "access-harness-refuses" "the harness refuses visibly with no server to test"
        fi
    fi
fi

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

# ---------------------------------------------------------------------------
# The Linux verification job (Task 6, REQ-E1.1, REQ-E1.2, REQ-E1.3, D-7). The
# macOS matrix entry above proves the negative -- a Mac provisions none of this
# -- and structurally cannot prove the positive, having neither apt nor
# systemd. A separate Ubuntu job does that, and the job's own green run is the
# verification (test-spec REQ-E1.1).
#
# What is checkable from a laptop is the job's *definition*, and the four
# properties below are the ones a later edit could quietly drop while the job
# kept passing: the release pin, the explicit host alias, the absence of any
# secret, and -- the one that matters most -- that the second run is actually
# *gated* rather than merely performed. The existing matrix runs the role twice
# and inspects `changed=`; that inline form is what Task 2's convergence found
# insufficient, since `changed=0` reads identically for a converged run and for
# a run that selected no tasks at all. So the gate is a script here, and this
# section asserts the job routes the second run through it.
# ---------------------------------------------------------------------------

linux_job_rc=0
python3 - "$workflow" "$repo_root/mise.toml" <<'PY' || linux_job_rc=$?
import pathlib
import re
import sys

import yaml

doc = yaml.safe_load(pathlib.Path(sys.argv[1]).read_text())
failed = []


def ok(name, msg):
    print(f"ok[{name}]: {msg}")


def bad(name, msg):
    print(f"FAIL[{name}]: {msg}", file=sys.stderr)
    failed.append(name)


# Found by its runner rather than by its name, so the assertions below are
# about the property the requirement names and not about an identifier this
# test and the workflow would have to agree on twice.
linux = {
    jid: job
    for jid, job in doc["jobs"].items()
    if str(job.get("runs-on", "")).startswith("ubuntu")
}
if len(linux) != 1:
    bad(
        "linux-job-exists",
        f"expected exactly one Ubuntu job running the provisioning, found {sorted(linux) or 'none'}",
    )
    sys.exit(1)
job_id, job = next(iter(linux.items()))
ok("linux-job-exists", f"`{job_id}` runs the provisioning on Ubuntu")

steps = job.get("steps") or []
runs = "\n".join(str(s.get("run", "")) for s in steps)


def step_env(name):
    """The value of an env var declared at job level or on any step."""
    for scope in [job.get("env") or {}] + [s.get("env") or {} for s in steps]:
        if name in scope:
            return str(scope[name])
    return None


# linux-job-pinned (D-7) -- an explicit release label, never the `-latest`
# alias, which resolves to the previous LTS and would exercise different major
# versions of both services than the target host will ever install.
label = str(job["runs-on"])
release = label[len("ubuntu-"):]
if not re.fullmatch(r"ubuntu-\d+\.\d+", label):
    bad("linux-job-pinned", f"`runs-on: {label}` is not a pinned Ubuntu release label")
elif release != "26.04":
    # Hardcoded, and deliberately so: D-7 pins the label to the release read
    # off the target host at kickoff (Ubuntu 26.04 LTS, `resolute`). A bump
    # here is the reviewable moment the decision asks for, not a nuisance.
    bad(
        "linux-job-pinned",
        f"pinned to `{label}`, but D-7 pins the runner to the target host's release (26.04)",
    )
else:
    ok("linux-job-pinned", f"pinned to `{label}`, the target host's release (D-7)")

# linux-job-release-asserted (REQ-E1.1, test-spec) -- the pin is only worth
# having if the label still means what it says, so the job reads the release
# back off the runner. The expected value is compared against `runs-on` here,
# because two spellings of one release is exactly the pair that drifts.
expected = step_env("EXPECTED_RELEASE")
if expected is None:
    bad(
        "linux-job-release-asserted",
        "no EXPECTED_RELEASE declared; nothing checks the label still means the release it names",
    )
elif expected != release:
    bad(
        "linux-job-release-asserted",
        f"EXPECTED_RELEASE is {expected!r} but `runs-on: {label}` says {release!r}",
    )
elif "/etc/os-release" not in runs:
    bad(
        "linux-job-release-asserted",
        "EXPECTED_RELEASE is declared but no step reads /etc/os-release to compare it against",
    )
else:
    ok("linux-job-release-asserted", f"the job asserts the runner really is {release}")

# linux-job-alias (Task 6 deliverable) -- set explicitly. Left unset, the
# playbook wrapper falls back to the macOS alias and says so on stderr:
# harmless, since `os_family` is what gates provisioning, and a misleading
# thing to leave in the log of the job that exists to prove Linux works.
alias = step_env("DOTFILES_HOST")
if alias is None:
    bad("linux-job-alias", "DOTFILES_HOST is not set; the wrapper would fall back to the macOS alias")
elif alias != "server":
    bad("linux-job-alias", f"DOTFILES_HOST is {alias!r}, not the Linux inventory alias 'server'")
else:
    ok("linux-job-alias", "the job names the Linux inventory alias explicitly")

# linux-job-no-secrets (REQ-E1.3) -- the job references no `secrets` context,
# and blanks the token the workflow-level env would otherwise hand every step.
# The second half is what makes the requirement executable rather than
# reviewed: with no credential in the environment, an authenticated fetch
# cannot succeed by accident, so a later edit that adds one fails rather than
# passing quietly. The workflow-level declaration itself is pre-existing and
# REQ-E1.4 forbids touching it, so it is shadowed here instead.
serialized = yaml.safe_dump(job)
if "secrets." in serialized:
    bad("linux-job-no-secrets", "the job references the `secrets` context")
elif step_env("GITHUB_TOKEN") != "":
    bad(
        "linux-job-no-secrets",
        "the job does not blank GITHUB_TOKEN, so it inherits the workflow-level token",
    )
else:
    ok("linux-job-no-secrets", "the job references no secret and runs with no token in its environment")

# linux-job-runs-twice (REQ-E1.2) -- provisioning, then the convergence re-run.
provision_steps = [s for s in steps if "-t services" in str(s.get("run", ""))]
if len(provision_steps) < 2:
    bad(
        "linux-job-runs-twice",
        f"{len(provision_steps)} step(s) run the provisioning; REQ-E1.2 needs a second run to gate",
    )
else:
    ok("linux-job-runs-twice", f"{len(provision_steps)} steps run the provisioning by tag")

# linux-job-matches-mise-task -- the job calls the playbook wrapper directly
# where the macOS matrix goes through `mise run <role>`, to keep its network
# surface down to what REQ-E1.3 permits. That is only free while the two stay
# the same command, and nothing else would notice them diverging: the mise task
# is what a human runs, the job is what CI runs, and a change to either would
# keep passing on its own terms.
try:
    import tomllib

    mise = tomllib.loads(pathlib.Path(sys.argv[2]).read_text())
    declared_run = " ".join((mise["tasks"]["services"]["run"]).split())
except ImportError:
    print(
        "skip[linux-job-matches-mise-task]: tomllib is unavailable (needs Python 3.11+)",
    )
except (KeyError, OSError, ValueError) as exc:
    # ValueError covers tomllib.TOMLDecodeError, which is a subclass of it: a
    # malformed mise.toml should name itself here rather than end this test in
    # a traceback that reads like the test is broken.
    bad("linux-job-matches-mise-task", f"could not read mise.toml's `services` task: {exc}")
else:
    if not any(declared_run in " ".join(str(s.get("run", "")).split()) for s in provision_steps):
        bad(
            "linux-job-matches-mise-task",
            f"no provisioning step runs mise's `services` task verbatim ({declared_run!r}); "
            "CI and `mise run services` have drifted apart",
        )
    else:
        ok("linux-job-matches-mise-task", f"the job runs mise's `services` task verbatim: {declared_run}")

# linux-job-gated (REQ-E1.2, REQ-E1.1) -- the three assertions the job's green
# result has to stand on. Named as paths so a rename cannot leave the job
# quietly running one fewer of them.
for name, script, why in (
    ("gate", "scripts/ansible-idempotency-gate.sh", "the second run is not gated on convergence"),
    ("runtime", "scripts/dev-services-runtime-test.sh", "nothing asserts the services are actually up"),
    ("access", "scripts/postgresql-access-test.sh", "the invoking account's access is unverified"),
):
    if script not in runs:
        bad(f"linux-job-{name}", f"no step runs {script}; {why}")
    else:
        ok(f"linux-job-{name}", f"the job runs {script}")

if failed:
    sys.exit(1)
PY
if [[ "$linux_job_rc" -ne 0 ]]; then
    fails=$((fails + 1))
fi

# ---------------------------------------------------------------------------
# The convergence gate itself (REQ-E1.2, REQ-C1.1). Its whole job is to tell
# three outcomes apart that a green log renders identically, so each is fed to
# it here as a recap fixture rather than left to be discovered the one time it
# matters:
#
#   converged   -- tasks ran and none changed. The only pass.
#   changed     -- tasks ran and some changed. The failure the gate exists for.
#   never ran   -- no task was selected at all, so `changed=0` is vacuously
#                  true. This is Task 2's finding: a tag that stops matching,
#                  or a guard that stops holding, silently converts the gate
#                  into a no-op that keeps reporting success.
#
# The fourth case, no recap at all, is the same class as the third: nothing to
# read, so nothing may be concluded.
# ---------------------------------------------------------------------------

gate="$repo_root/scripts/ansible-idempotency-gate.sh"
if [[ ! -x "$gate" ]]; then
    fail "gate-present" "$gate is missing or not executable"
else
    pass "gate-present" "the convergence gate is present and executable"

    recap() {
        printf 'PLAY RECAP %s\n%s\n' \
            "*********************************************************" "$1"
    }

    gate_case() {
        local name=$1 expect=$2 recap_line=$3 needle=$4 out rc=0
        out=$(recap "$recap_line" | "$gate" 2>&1) || rc=$?
        if [[ "$expect" == "pass" && "$rc" -ne 0 ]]; then
            fail "$name" "the gate rejected a recap it should accept:
$(sed 's/^/    /' <<<"$out")"
        elif [[ "$expect" == "fail" && "$rc" -eq 0 ]]; then
            fail "$name" "the gate accepted a recap it must reject:
$(sed 's/^/    /' <<<"$out")"
        elif [[ -n "$needle" ]] && ! grep -qi -- "$needle" <<<"$out"; then
            fail "$name" "the gate's verdict does not name '$needle':
$(sed 's/^/    /' <<<"$out")"
        else
            pass "$name" "the gate reports '$expect' for the $name fixture"
        fi
    }

    # Recap lines carry ansible's full field set, `rescued` and `ignored`
    # included, rather than the shortened form the assertions strictly need:
    # the gate reads fields by name, and a fixture that omits half of them
    # would not notice if it stopped.
    converged="ok=7    changed=0    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0"
    gate_case "gate-converged" pass "server                     : $converged" "ok=7"
    gate_case "gate-changed" fail \
        "server                     : ok=7 changed=3 unreachable=0 failed=0 skipped=2 rescued=0 ignored=0" \
        "changed"
    gate_case "gate-never-ran" fail \
        "server                     : ok=0 changed=0 unreachable=0 failed=0 skipped=9 rescued=0 ignored=0" \
        "no task"
    gate_case "gate-failed" fail \
        "server                     : ok=5 changed=0 unreachable=0 failed=2 skipped=0 rescued=0 ignored=1" \
        "failed"

    # A coloured recap, which is what a force_color or `script`-wrapped run
    # hands the gate. Every other fixture is plain, so without this case the
    # escape stripping goes unexercised and could rot into a no-op. The escape
    # is put in front of `PLAY RECAP` deliberately: that is where an unstripped
    # run stops matching the header at all, so the gate refuses a run that
    # converged perfectly well. A colour only on the host line would leave
    # enough of the fields readable that this case could pass without the
    # stripping working -- which is the fixture testing nothing.
    coloured_rc=0
    coloured_out=$(printf '\033[0;36mPLAY RECAP ****\033[0m\n\033[0;32mserver : %s\033[0m\n' \
        "$converged" | "$gate" 2>&1) || coloured_rc=$?
    if [[ "$coloured_rc" -ne 0 ]]; then
        fail "gate-coloured" "the gate rejected a converged recap because it was coloured:
$(sed 's/^/    /' <<<"$coloured_out")"
    elif [[ "$coloured_out" == *$'\033'* ]]; then
        fail "gate-coloured" "the gate passed the recap but echoed escapes back into its verdict:
$(sed 's/^/    /' <<<"$coloured_out")"
    else
        pass "gate-coloured" "the gate reads a coloured recap and reports a clean verdict"
    fi

    no_recap_rc=0
    no_recap_out=$(printf 'PLAY [Configure development environment] ***\n' | "$gate" 2>&1) ||
        no_recap_rc=$?
    if [[ "$no_recap_rc" -eq 0 ]]; then
        fail "gate-no-recap" "the gate passed output containing no PLAY RECAP; it read nothing"
    elif ! grep -qi 'recap' <<<"$no_recap_out"; then
        fail "gate-no-recap" "the gate refused without naming the missing recap:
$(sed 's/^/    /' <<<"$no_recap_out")"
    else
        pass "gate-no-recap" "the gate refuses output it cannot read a recap from"
    fi
fi

# ---------------------------------------------------------------------------
# The runtime harness (REQ-E1.1). Like the access harness above, proving the
# positive needs a provisioned host, so what is checkable here is that it
# refuses visibly rather than passing vacuously when the units are absent.
# ---------------------------------------------------------------------------

runtime_test="$repo_root/scripts/dev-services-runtime-test.sh"
if [[ ! -x "$runtime_test" ]]; then
    fail "runtime-harness-present" "$runtime_test is missing or not executable"
else
    pass "runtime-harness-present" "the runtime harness is present and executable"

    runtime_out="$workdir/runtime.out"
    runtime_rc=0
    "$runtime_test" >"$runtime_out" 2>&1 || runtime_rc=$?
    if [[ "$runtime_rc" -eq 0 ]]; then
        # A pass is only legitimate on a host where the provisioning has run,
        # which is the CI job and the target host. Distinguished by asking the
        # declaration's own first unit, so this stays correct if the list grows.
        first_unit=$(python3 -c '
import sys, yaml
d = yaml.safe_load(open(sys.argv[1])) or {}
print((d.get("services_dev_services") or [{}])[0].get("unit", ""))
' "$defaults")
        if [[ -n "$first_unit" ]] && systemctl is-active --quiet "$first_unit" 2>/dev/null; then
            pass "runtime-harness-refuses" \
                "the declared services are provisioned here, so the harness passed for real"
        else
            fail "runtime-harness-refuses" \
                "the harness exited 0 with '$first_unit' inactive; it proved nothing"
        fi
    elif ! grep -qiE 'systemd|systemctl|not active|inactive|unit' "$runtime_out"; then
        fail "runtime-harness-refuses" "the harness failed without naming what was missing:
$(sed 's/^/    /' "$runtime_out")"
    else
        pass "runtime-harness-refuses" "the harness reports visibly with the services absent"
    fi
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
