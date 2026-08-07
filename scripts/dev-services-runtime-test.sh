#!/usr/bin/env bash
# Runtime verification for the declared dev-services layer (specs/dev-services
# Task 6, REQ-E1.1, REQ-A1.3, REQ-C1.2). Answers, against the running system
# rather than against the playbook's own report:
#
#   Running   -- every declared unit is active.
#   Enabled   -- every declared unit is enabled, so a reboot brings it back.
#   Reachable -- every declared address and port accepts a TCP connection.
#
# Driven entirely from roles/services/defaults/main.yml, which is the whole
# point: the declaration is the single place a service is added (REQ-B1.1), so
# a service that is declared but never provisioned fails here without anyone
# remembering to extend this file. Nothing below names PostgreSQL or Valkey.
#
# Why this exists next to the playbook's own `wait_for` step. That step runs
# inside the run whose result is in question, so it can only ever say the run
# reached it. This one runs afterwards, from outside, and asks systemd and a
# socket. The distinction is what lets the convergence gate
# (scripts/ansible-idempotency-gate.sh) mean something: `changed=0` is only
# good news once something independent has established the services are up.
# Run the two as a pair -- this first, the gate over the second run -- and
# together they separate "converged" from "quietly stopped provisioning",
# which neither can do alone.
#
# `enabled` is asserted rather than assumed from `active`, because the two come
# apart in exactly the case that matters: a unit started by hand on a host that
# was never told to bring it back is active now and gone after the next reboot,
# which is REQ-C1.2's whole subject.
#
# Every precondition it cannot meet is a non-zero exit naming the fault, never
# a quiet pass -- the same posture scripts/postgresql-access-test.sh takes, for
# the same reason: a verification script that exits 0 having proved nothing
# reports coverage that does not exist.
#
# Run: scripts/dev-services-runtime-test.sh
# Exit 0 = every assertion passed. Callers: Task 6's CI job, Task 7's host
# convergence loop.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
defaults="$repo_root/roles/services/defaults/main.yml"

fails=0
pass() { echo "ok[$1]: $2"; }
fail() {
    echo "FAIL[$1]: $2" >&2
    fails=$((fails + 1))
}
# "$*", not "$1": the refusals below are written across two arguments so they
# fit on a line here, and a one-argument echo would print half of each.
refuse() {
    echo "REFUSED: $*" >&2
    exit 2
}

if ! command -v systemctl >/dev/null 2>&1; then
    refuse "systemctl is not on PATH. The declared services are systemd units on a" \
        "Linux host (REQ-B1.4); there is nothing here to verify."
fi

if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import yaml' 2>/dev/null; then
    refuse "python3 with PyYAML is needed to read the declaration; it ships with" \
        "ansible's dependencies."
fi

if [[ ! -r "$defaults" ]]; then
    refuse "$defaults is not readable, so there is no declaration to verify against."
fi

# Emitted as tab-separated fields rather than parsed in bash, so a name
# containing a space stays one field. Ordered as declared, so the output reads
# in the same order as the file it came from.
declaration=$(python3 - "$defaults" <<'PY'
import pathlib
import sys

import yaml

declared = (yaml.safe_load(pathlib.Path(sys.argv[1]).read_text()) or {}).get(
    "services_dev_services"
)
if not isinstance(declared, list) or not declared:
    sys.exit("services_dev_services is missing, empty, or not a list")
for entry in declared:
    missing = [f for f in ("name", "unit", "listen_address", "listen_port") if not entry.get(f)]
    if missing:
        sys.exit(f"declared entry {entry!r} is missing: {', '.join(missing)}")
    print("\t".join(str(entry[f]) for f in ("name", "unit", "listen_address", "listen_port")))
PY
) || refuse "could not read the declaration: $declaration"

if [[ -z "$declaration" ]]; then
    refuse "the declaration parsed to no services at all; there is nothing to assert."
fi

count=0
while IFS=$'\t' read -r name unit address port; do
    count=$((count + 1))

    # `is-active` prints its verdict on stdout and exits non-zero for anything
    # that is not active, including a unit that does not exist -- which is the
    # never-provisioned case, and is reported with the word systemd used rather
    # than translated into one of ours.
    state=$(systemctl is-active "$unit" 2>/dev/null || true)
    if [[ "$state" != "active" ]]; then
        fail "running" "$name ($unit) is '$state', not active"
    else
        pass "running" "$name ($unit) is active"
    fi

    # `enabled-runtime` is deliberately not accepted: it means the enablement
    # lives in /run and disappears at reboot, which is the failure this
    # assertion is about. `alias`, `static` and `indirect` are likewise not
    # persistence -- if a declared unit reports one of those, the declaration
    # names the wrong unit and should say so here.
    enablement=$(systemctl is-enabled "$unit" 2>/dev/null || true)
    if [[ "$enablement" != "enabled" ]]; then
        fail "enabled" "$name ($unit) is '$enablement', not enabled; it would not survive a reboot"
    else
        pass "enabled" "$name ($unit) is enabled"
    fi

    # A real connection, not a listening-socket enumeration: a socket in the
    # table with nothing accepting behind it is precisely what a oneshot meta
    # unit reporting `active` can leave you with. bash's /dev/tcp needs no
    # extra package on either the runner or the host.
    #
    # The redirect is opened in a subshell so a refused connection cannot take
    # the whole script down under `set -e`, and the timeout bounds a port that
    # accepts the SYN and then says nothing.
    #
    # The address and port arrive as arguments rather than being pasted into
    # the `-c` string. They come from a repo-tracked declaration, so nothing
    # hostile is in reach today; a value concatenated into a shell command is
    # the wrong shape regardless, and this is the same reasoning the role's
    # own `argv` invocations in tasks/postgresql.yml are written down for.
    if timeout 5 bash -c 'exec 3<>/dev/tcp/"$1"/"$2"' _ "$address" "$port" 2>/dev/null; then
        pass "reachable" "$name accepts a connection on $address:$port"
    else
        fail "reachable" "$name does not accept a connection on its declared $address:$port"
    fi
done <<<"$declaration"

if [[ "$fails" -ne 0 ]]; then
    echo "dev-services-runtime-test: $fails assertion(s) failed across $count declared service(s)" >&2
    exit 1
fi
echo "dev-services-runtime-test: $count declared service(s) running, enabled and reachable"
