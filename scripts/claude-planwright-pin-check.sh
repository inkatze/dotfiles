#!/usr/bin/env bash
# Fails when the tracked Claude settings name a concrete planwright version
# directory. Such a rule matches nothing after a planwright update, and nothing
# else reports it: the session it served is just blocked again. Write the
# version segment as `*` instead.
#
# Prints OK, or FAILED naming each pinned version. Usage:
#   claude-planwright-pin-check.sh <tracked-settings>
set -euo pipefail

tracked="${1:?tracked settings path required}"

jq -e . "$tracked" >/dev/null 2>&1 || { echo "FAILED: tracked settings is not valid JSON: $tracked" >&2; exit 2; }

pinned=$(jq -r '.. | strings
  | scan("plugins/cache/planwright/planwright/([^/]+)/") | .[0]
  | select(. != "*")' "$tracked" | sort -u)
if [ -n "$pinned" ]; then
    printf 'FAILED: tracked settings pin planwright %s; write the version segment as *\n' \
        "$(printf '%s' "$pinned" | paste -sd, -)" >&2
    exit 1
fi
echo OK
