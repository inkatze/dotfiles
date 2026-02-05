#!/usr/bin/env bash
set -euo pipefail

PERSONALHOST="crojtini"
ALTHOST="panela"

hostname=$(hostname)

if [[ "$hostname" == *"$PERSONALHOST"* ]]; then
    current_host="personal"
elif [[ "$hostname" == *"$ALTHOST"* ]]; then
    current_host="alt"
else
    current_host="work"
fi

echo "Running on host: $current_host"
exec ansible-playbook -l "$current_host" main.yml "$@"
