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
HOST_OVERRIDE_FILE="${DOTFILES_HOST_FILE:-$HOME/.config/dotfiles/host}"
if [[ -n "${DOTFILES_HOST:-}" ]]; then
    current_host="$DOTFILES_HOST"
elif [[ -f "$HOST_OVERRIDE_FILE" ]]; then
    current_host="$(tr -d '[:space:]' <"$HOST_OVERRIDE_FILE")"
elif [[ "$hostname" == *"$ALTHOST"* ]]; then
    current_host="alt"
else
    current_host="work"
    echo "playbook.sh: no machine-local alias configured, defaulting to '${current_host}'." >&2
    echo "playbook.sh: if this is not the work host, export DOTFILES_HOST or write the alias to ${HOST_OVERRIDE_FILE}." >&2
fi

echo "Running on host: $current_host"
exec ansible-playbook -l "$current_host" main.yml "$@"
