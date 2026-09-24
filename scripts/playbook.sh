#!/usr/bin/env bash
set -euo pipefail

ALTHOST="panela"

hostname=$(hostname)

# Machine-local host-alias override: the DOTFILES_HOST env var, or an
# untracked file naming this machine's inventory alias. This keeps a host's
# real hostname out of this public repo (REQ-F1.1). The `personal` alias used
# to be matched by hostname; it is resolved here now, so that host must name
# itself. `work` remains the default so a machine with no configuration (and
# CI, which runs the roles on a throwaway runner) keeps working, but the
# fallback warns rather than silently targeting the wrong inventory host.
#
# The file counts only when it names something: `-l ""` is no limit at all to
# Ansible, so an empty or whitespace-only file would otherwise run every
# inventory host's configuration against this machine.
#
# Read only when the env var is unset: under `set -e` an unreadable file would
# otherwise abort the run that DOTFILES_HOST was exported to get around.
HOST_OVERRIDE_FILE="${DOTFILES_HOST_FILE:-$HOME/.config/dotfiles/host}"
host_from_file=""
if [[ -z "${DOTFILES_HOST:-}" && -f "$HOST_OVERRIDE_FILE" ]]; then
    host_from_file="$(tr -d '[:space:]' <"$HOST_OVERRIDE_FILE")"
fi
if [[ -n "${DOTFILES_HOST:-}" ]]; then
    current_host="$DOTFILES_HOST"
elif [[ -n "$host_from_file" ]]; then
    current_host="$host_from_file"
elif [[ "$hostname" == *"$ALTHOST"* ]]; then
    current_host="alt"
else
    current_host="work"
    echo "playbook.sh: no machine-local alias configured, defaulting to '${current_host}'." >&2
    echo "playbook.sh: if this is not the work host, export DOTFILES_HOST or write the alias to ${HOST_OVERRIDE_FILE}." >&2
fi

# Machine-local 1Password account selector, same shape as the host alias above.
#
# `op` infers the account when exactly one is configured, which is why nothing
# here ever needed it. A host with two -- a company tenant alongside the
# personal account, which is the normal state of a managed work Mac -- makes
# every `op` call fail with "multiple accounts found. Use the --account flag or
# set the OP_ACCOUNT environment variable". That is four call sites: the GitHub
# MCP PAT sync, the Pushover credential read in roles/osx, and the `op` probes
# in roles/claude and roles/ssh. Exporting once here covers all of them rather
# than threading --account through each.
#
# Untracked for the REQ-F1.1 reason the rest of these files exist: the value
# names an employer's 1Password tenant. An absent file means nothing is
# exported and single-account hosts behave exactly as before, and an empty one
# is treated the same rather than exported as an empty selector. An
# already-exported OP_ACCOUNT wins, so a one-off run can override it.
OP_ACCOUNT_FILE="${DOTFILES_OP_ACCOUNT_FILE:-$HOME/.config/dotfiles/op-account}"
if [[ -z "${OP_ACCOUNT:-}" && -f "$OP_ACCOUNT_FILE" ]]; then
    op_account_from_file="$(tr -d '[:space:]' <"$OP_ACCOUNT_FILE")"
    if [[ -n "$op_account_from_file" ]]; then
        export OP_ACCOUNT="$op_account_from_file"
    fi
fi

echo "Running on host: $current_host"
exec ansible-playbook -l "$current_host" main.yml "$@"
