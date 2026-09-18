#!/usr/bin/env bash
# Merges the tracked Claude settings into the live ~/.claude/settings.json.
#
# Non-hook keys merge with jq's `*`, as before. Hook arrays do NOT: jq's `*`
# replaces them, so declaring an event wiped whatever else installed hooks
# there (an MDM, another tool). Instead each declared event is rebuilt as
# "foreign entries kept, ours replaced", where ours means an entry invoking
# $HOME/.claude/scripts/. Declaring an empty array therefore still removes our
# hooks from that event without touching anyone else's.
#
# Prints OK, or CHANGED after writing. Usage: claude-settings-merge.sh <live> <tracked>
set -euo pipefail

live="${1:?live settings path required}"
managed="${2:?tracked settings path required}"

[ -f "$managed" ] || { echo "FAILED: tracked settings not found: $managed" >&2; exit 1; }
if [ ! -e "$live" ]; then
    mkdir -p "$(dirname "$live")"
    printf '{}\n' >"$live"
fi
jq -e . "$live" >/dev/null 2>&1 || { echo "FAILED: live settings is not valid JSON: $live" >&2; exit 2; }
jq -e . "$managed" >/dev/null 2>&1 || { echo "FAILED: tracked settings is not valid JSON: $managed" >&2; exit 3; }

updated=$(jq -n --slurpfile l "$live" --slurpfile m "$managed" '
  def ours: (.hooks // []) | any((.command // "") | startswith("$HOME/.claude/scripts/"));
  ($l[0]) as $live | ($m[0]) as $mgd
  | ($live.hooks // {}) as $lh
  | ($mgd.hooks  // {}) as $mh
  | ($live * $mgd)
  | .hooks = (
      reduce ((($lh | keys_unsorted) + ($mh | keys_unsorted)) | unique)[] as $k ({};
        .[$k] = (
          if ($mh | has($k))
          then (($lh[$k] // []) | map(select(ours | not))) + ($mh[$k])
          else $lh[$k]
          end
        )
      )
    )
')

if [ "$(cat "$live")" = "$updated" ]; then
    echo OK
else
    tmp=$(mktemp "${live}.XXXXXX")
    printf '%s\n' "$updated" >"$tmp"
    mv "$tmp" "$live"
    echo CHANGED
fi
