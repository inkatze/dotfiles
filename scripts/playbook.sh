#!/usr/bin/env bash
set -euo pipefail

ALTHOST="panela"

hostname=$(hostname)

# Not printf %q: stock macOS bash 3.2 passes non-ASCII bytes through it raw.
escape() { printf '%s' "$1" | LC_ALL=C sed -n 'l' | LC_ALL=C sed 's/\$$//'; }

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
# Read only when the env var is unset or empty: under `set -e` an unreadable
# file would otherwise abort the run that DOTFILES_HOST was exported to get
# around.
HOST_OVERRIDE_FILE="${DOTFILES_HOST_FILE:-$HOME/.config/dotfiles/host}"
host_from_file=""
if [[ -z "${DOTFILES_HOST:-}" && -f "$HOST_OVERRIDE_FILE" ]]; then
    # C locale: macOS tr under UTF-8 strips NBSP as whitespace, hiding a malformed file.
    host_from_file="$(LC_ALL=C tr -d '[:space:]' <"$HOST_OVERRIDE_FILE")"
    if [[ -z "$host_from_file" ]]; then
        echo "playbook.sh: ${HOST_OVERRIDE_FILE} exists but names no alias; treating it as absent." >&2
    fi
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

# Ansible splits a limit on `,` and `:` and drops the pieces that strip to
# nothing, so a value such as `,` or a non-ASCII space survives the checks
# above and still reaches it as no limit at all, and a leading `-` or `!`
# reaches it as an option or a negation. An alias is a plain ASCII name;
# anything else is refused rather than passed through. Pinned to the C locale
# so the accepted set is the same under every LANG; the echoed value goes
# through escape() so it never reaches the terminal raw.
if ! printf '%s' "$current_host" | LC_ALL=C grep -qE '^[A-Za-z0-9][A-Za-z0-9_-]*$'; then
    printf 'playbook.sh: alias %s is not a plain host name; refusing to run.\n' "$(escape "$current_host")" >&2
    exit 1
fi

# A plain name can still be a group (`all`, `ungrouped`, `secrets`), which
# widens the run to several hosts the same way. Only a host entry from the
# inventory is accepted, read from the file so a new alias needs no edit here.
inventory="$(cd -- "$(dirname "$0")/.." && pwd -P)/hosts"
if ! awk '/^[^#[[:space:]]/ { print $1 }' "$inventory" | LC_ALL=C grep -qxF -- "$current_host"; then
    printf 'playbook.sh: alias %s is not a host in %s; refusing to run.\n' "$(escape "$current_host")" "$inventory" >&2
    exit 1
fi

# Machine-local 1Password account selector: an untracked file with an env
# override, like the host alias above, without its empty-file note.
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
    op_account_from_file="$(LC_ALL=C tr -d '[:space:]' <"$OP_ACCOUNT_FILE")"
    if [[ -n "$op_account_from_file" ]]; then
        # The forms op --account takes (shorthand, sign-in address, account or user ID); anything else fails every op call confusingly.
        if ! printf '%s' "$op_account_from_file" | LC_ALL=C grep -qE '^[A-Za-z0-9][A-Za-z0-9._@-]*$'; then
            printf 'playbook.sh: %s holds %s, not a 1Password account; refusing to run.\n' "$OP_ACCOUNT_FILE" "$(escape "$op_account_from_file")" >&2
            exit 1
        fi
        export OP_ACCOUNT="$op_account_from_file"
    fi
fi

echo "Running on host: $current_host"
exec ansible-playbook -l "$current_host" main.yml "$@"
