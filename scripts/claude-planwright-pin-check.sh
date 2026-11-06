#!/usr/bin/env bash
# Fails when the tracked Claude settings name a planwright version directory
# that is not the installed planwright. Such a rule matches nothing after a
# planwright update, and nothing else reports it: the session it served is
# just blocked again. Bump every pinned version in the tracked settings.json.
# A `*` in the version segment is a glob, not a pin, and never goes stale.
#
# Prints OK, or FAILED naming each stale version. Usage:
#   claude-planwright-pin-check.sh <tracked-settings> <installed_plugins.json>
set -euo pipefail

tracked="${1:?tracked settings path required}"
installed="${2:?installed_plugins.json path required}"

jq -e . "$tracked" >/dev/null 2>&1 || { echo "FAILED: tracked settings is not valid JSON: $tracked" >&2; exit 2; }

pinned=$(jq -r '.. | strings
  | scan("plugins/cache/planwright/planwright/([^/]+)/") | .[0]
  | select(. != "*")' "$tracked" | sort -u)
[ -n "$pinned" ] || { echo OK; exit 0; }

jq -e . "$installed" >/dev/null 2>&1 || { echo "FAILED: settings pin planwright, but no readable plugin record at $installed" >&2; exit 2; }
current=$(jq -r '(.plugins["planwright@planwright"] // [])[] | .version' "$installed" | sort -u)

stale=$(comm -23 <(printf '%s\n' "$pinned") <(printf '%s\n' "$current"))
if [ -n "$stale" ]; then
    printf 'FAILED: tracked settings pin planwright %s, installed is %s; bump the pinned rules\n' \
        "$(printf '%s' "$stale" | paste -sd, -)" "$(printf '%s' "${current:-none}" | paste -sd, -)" >&2
    exit 1
fi
echo OK
