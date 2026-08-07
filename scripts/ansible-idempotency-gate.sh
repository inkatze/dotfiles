#!/usr/bin/env bash
# Convergence gate over an ansible-playbook run's output (specs/dev-services
# REQ-E1.2, REQ-C1.1). Reads a recap and decides one thing: may this run be
# called converged?
#
#   Run: scripts/ansible-idempotency-gate.sh [run.log]      # stdin if omitted
#   Exit 0 = converged. 1 = did not converge. 2 = could not tell.
#
# Why a script rather than the four lines of inline shell the macOS matrix
# uses. That form greps the output for `changed=[1-9]` and fails if it finds
# one, which is correct as far as it goes and stops exactly one step short:
# `changed=0` is also what a run reports when it selected no tasks at all.
# Task 2's convergence found that the hard way -- a role whose tag stops
# matching, or whose platform guard stops holding, keeps reporting a clean
# idempotency check forever while provisioning nothing. The gate that cannot
# fail and the gate that has converged look identical in a green log.
#
# So `ok=0` is a failure here, not a pass, and so is a recap that is absent
# entirely. Both mean the same thing: there is no evidence of work, and the
# absence of evidence is being read as evidence of convergence. That is the
# only interesting thing this script does; the `changed=0` half is the easy
# half and was never the one that went wrong.
#
# What it deliberately does NOT do is assert the services are up. `ok>0` says
# tasks ran, not that they achieved anything, and no recap arithmetic can close
# that gap. scripts/dev-services-runtime-test.sh answers it directly, against
# systemd and a socket, and the two are meant to be run as a pair: the runtime
# harness proves the provisioning worked, this proves it has stopped changing
# anything. Neither substitutes for the other.
set -euo pipefail

refuse() {
    echo "REFUSED: $*" >&2
    exit 2
}

case "${1:-}" in
-h | --help)
    sed -n '2,7p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
esac

if [[ $# -gt 1 ]]; then
    refuse "expected at most one log file, got $#. Usage:" \
        "ansible-idempotency-gate.sh [run.log]"
fi

source=${1:--}
if [[ "$source" == "-" ]]; then
    output=$(cat)
    source="stdin"
elif [[ ! -r "$source" ]]; then
    refuse "$source is not readable"
else
    output=$(cat -- "$source")
fi

# Ansible colours its recap when it believes it is writing to a terminal, and
# `script`-wrapped or force_color runs reach here with the escapes intact. A
# gate that silently matched nothing because of them would report exactly the
# vacuous pass this script exists to prevent, so they are stripped rather than
# assumed absent.
output=$(printf '%s\n' "$output" | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g')

if ! grep -q '^PLAY RECAP' <<<"$output"; then
    refuse "no PLAY RECAP in $source, so nothing can be concluded about convergence." \
        "The run did not reach the end of a play: read the output for the real failure."
fi

# One awk pass over the recap, so the verdict and the reasons it prints cannot
# disagree about a line. `ok=` is required rather than optional: a recap line
# without it is a format this gate does not understand, and guessing would be
# the vacuous pass again.
verdict=$(awk '
    /^PLAY RECAP/ { recap = 1; next }
    !recap { next }
    # Recap lines are `host : ok=N changed=N ...`; a blank line ends the block.
    !/:[[:space:]]+ok=/ { next }
    {
        host = $1
        hosts++
        for (i = 1; i <= NF; i++) {
            if (split($i, kv, "=") == 2) stat[kv[1]] = kv[2] + 0
        }
        if (stat["ok"] == 0) {
            printf "no-tasks\t%s\tselected no tasks at all (ok=0)\n", host
        }
        if (stat["changed"] > 0) {
            printf "changed\t%s\tchanged %d task(s)\n", host, stat["changed"]
        }
        if (stat["failed"] > 0) {
            printf "failed\t%s\tfailed %d task(s)\n", host, stat["failed"]
        }
        if (stat["unreachable"] > 0) {
            printf "unreachable\t%s\twas unreachable\n", host
        }
        # `split("", stat)` rather than `delete stat`: the same clear, spelled
        # in the form every awk on either platform accepts.
        split("", stat)
    }
    END { printf "hosts\t%d\n", hosts }
' <<<"$output")

hosts=$(awk -F'\t' '$1 == "hosts" { print $2 }' <<<"$verdict")
if [[ "$hosts" -eq 0 ]]; then
    refuse "the PLAY RECAP in $source lists no host in the expected" \
        "\`host : ok=N changed=N ...\` form; the gate cannot read it."
fi

problems=$(awk -F'\t' '$1 != "hosts" { printf "    %s: %s\n", $2, $3 }' <<<"$verdict")
if [[ -n "$problems" ]]; then
    echo "FAIL: the run did not converge:" >&2
    printf '%s\n' "$problems" >&2
    # Said out loud only when it applies, because it is the diagnosis a reader
    # is least likely to reach on their own: ok=0 looks like success everywhere
    # else in this output.
    if grep -q 'no-tasks' <<<"$verdict"; then
        echo "  A host reporting ok=0 provisioned nothing at all. That is a gate that" >&2
        echo "  stopped working, not a converged run -- check the tag selector and the" >&2
        echo "  role's platform guard before reading this as an idempotency problem." >&2
    fi
    exit 1
fi

echo "ok: $hosts host(s) converged -- tasks ran and none reported a change"
