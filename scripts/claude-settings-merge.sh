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
# An allow or deny rule whose pattern opens with $HOME/ is written expanded, because
# Claude Code matches a Bash rule against the literal command and never
# expands it; the tracked file stays free of any one machine's home path.
#
# permissions.allow and permissions.deny are a union, not a replacement: the
# tracked rules first, then the optional fragment's (a machine-local file
# holding only those two lists, rendered from 1Password for rules that must not
# be committed), then any the live file alone carries, each rule once. So a rule
# Claude Code or a person added survives, and dropping a rule from the tracked
# file no longer removes it from a live one; delete it there by hand too.
#
# Prints OK, or CHANGED after writing.
# Usage: claude-settings-merge.sh <live> <tracked> [<fragment>]; a missing
# fragment is the same as an empty one.
set -euo pipefail

live="${1:?live settings path required}"
managed="${2:?tracked settings path required}"
fragment="${3:-}"

[ -f "$managed" ] || { echo "FAILED: tracked settings not found: $managed" >&2; exit 1; }
if [ ! -e "$live" ]; then
    mkdir -p "$(dirname "$live")"
    printf '{}\n' >"$live"
fi
jq -e . "$live" >/dev/null 2>&1 || { echo "FAILED: live settings is not valid JSON: $live" >&2; exit 2; }
jq -e . "$managed" >/dev/null 2>&1 || { echo "FAILED: tracked settings is not valid JSON: $managed" >&2; exit 3; }
frag_json='{}'
if [ -n "$fragment" ] && { [ -e "$fragment" ] || [ -L "$fragment" ]; }; then
    # Checked here because the fragment may only add rules: any other key in it
    # would otherwise override a tracked or app-owned setting unseen.
    jq -e '
      type == "object" and (keys - ["permissions"] == [])
      and ((.permissions // {}) | type == "object" and (keys - ["allow", "deny"] == [])
           and all(.[]; type == "array" and all(.[]; type == "string" and length > 0)))
    ' "$fragment" >/dev/null 2>&1 \
        || { echo "FAILED: settings fragment must hold only permissions.allow and permissions.deny string lists: $fragment" >&2; exit 4; }
    frag_json=$(jq -c . "$fragment")
fi

# $HOME is passed in because a hook command may be recorded either as the
# literal "$HOME/..." the tracked file uses or already expanded; missing the
# expanded form would treat our own entry as foreign and then duplicate it.
updated=$(jq -n --slurpfile l "$live" --slurpfile m "$managed" --argjson f "$frag_json" --arg home "$HOME" '
  def owned:
    (.command // "") as $c
    | ($c | startswith("$HOME/.claude/scripts/"))
      or ($c | startswith($home + "/.claude/scripts/"));
  def strip_ours: (.hooks // []) | map(select(owned | not));
  def expand_home:
    map(if type == "string" and test("^[A-Za-z_]+\\(\\$HOME/")
        then sub("\\(\\$HOME/"; "(" + $home + "/")
        else . end);
  # First occurrence wins, so the order is stable across runs.
  def union_rules: reduce .[] as $r ([]; if index([$r]) then . else . + [$r] end);
  def rules($s; $k): ($s.permissions[$k]? // []) | if type == "array" then . else [] end;
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
  | reduce ("allow", "deny") as $k (.;
      (rules($mgd; $k) + rules($f; $k) + rules($live; $k) | expand_home) as $all
      | if ($all | length) > 0 then .permissions[$k] = ($all | union_rules) else . end)
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
