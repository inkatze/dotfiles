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

# $HOME is passed in because a hook command may be recorded either as the
# literal "$HOME/..." the tracked file uses or already expanded; missing the
# expanded form would treat our own entry as foreign and then duplicate it.
updated=$(jq -n --slurpfile l "$live" --slurpfile m "$managed" --arg home "$HOME" '
  def owned:
    (.command // "") as $c
    | ($c | startswith("$HOME/.claude/scripts/"))
      or ($c | startswith($home + "/.claude/scripts/"));
  def strip_ours: (.hooks // []) | map(select(owned | not));
  ($l[0]) as $live | ($m[0]) as $mgd
  | ($live.hooks // {}) as $lh
  | ($mgd.hooks  // {}) as $mh
  | ($live * $mgd)
  | .hooks = (
      reduce ((($lh | keys_unsorted) + ($mh | keys_unsorted)) | unique)[] as $k ({};
        .[$k] = (
          if ($mh | has($k))
          then (
            ($lh[$k] // [])
            | map(.hooks = strip_ours | select((.hooks // []) | length > 0))
          ) + ($mh[$k])
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
    # 0600 asserted, not inherited: this file carries an `env` block, and mktemp
    # would hand its own 0600 to the result silently anyway.
    chmod 600 "$tmp"
    mv "$tmp" "$live"
    echo CHANGED
fi
