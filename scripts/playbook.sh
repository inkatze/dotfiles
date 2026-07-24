#!/usr/bin/env bash
set -euo pipefail

PERSONALHOST="crojtini"
ALTHOST="panela"

hostname=$(hostname)

# Machine-local host-alias override: the DOTFILES_HOST env var, or a
# gitignored file naming this machine's inventory alias. This keeps a host's
# real hostname out of the repo (REQ-F1.1 for the linux-migration `server`,
# which sets its alias here). Mac hosts have neither and fall through to the
# hostname patterns below, so their behavior is unchanged.
HOST_OVERRIDE_FILE="${DOTFILES_HOST_FILE:-$HOME/.config/dotfiles/host}"
if [[ -n "${DOTFILES_HOST:-}" ]]; then
    current_host="$DOTFILES_HOST"
elif [[ -f "$HOST_OVERRIDE_FILE" ]]; then
    current_host="$(tr -d '[:space:]' <"$HOST_OVERRIDE_FILE")"
elif [[ "$hostname" == *"$PERSONALHOST"* ]]; then
    current_host="personal"
elif [[ "$hostname" == *"$ALTHOST"* ]]; then
    current_host="alt"
else
    current_host="work"
fi

echo "Running on host: $current_host"
exec ansible-playbook -l "$current_host" main.yml "$@"
