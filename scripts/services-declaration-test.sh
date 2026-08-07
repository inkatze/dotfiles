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

for rel in listing.read_text().split():
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
