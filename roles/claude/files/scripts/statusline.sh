#!/usr/bin/env bash
# Claude Code status line: directory, git branch, model, context used.
# Reads the session JSON on stdin and prints one line; any field Claude Code
# omits or sends as null drops its segment.
set -uo pipefail

# One jq pass for all fields. The unit separator is not whitespace, so `read`
# keeps empty fields in place, and control characters are stripped from every
# value so a hostile directory name cannot write escape sequences to the
# terminal.
fields=$(jq -r '
  def text: if type == "string" then gsub("[\u0000-\u001f\u007f]"; "") else "" end;
  [ ((.workspace.current_dir // .cwd) | text),
    (.model.display_name | text),
    (.context_window.used_percentage
      | if type == "number" then floor | tostring else "" end)
  ] | join("\u001f")
' 2>/dev/null) || exit 0

IFS=$'\x1f' read -r dir model pct <<<"$fields"

location=""
if [ -n "$dir" ]; then
    location="${dir%/}"
    location="${location##*/}"
    location="${location:-/}"
    # An inherited GIT_DIR (Claude started from a git hook) outranks -C.
    branch=$(unset GIT_DIR GIT_WORK_TREE; git -C "$dir" branch --show-current 2>/dev/null) || branch=""
    [ -n "$branch" ] && location="$location  $branch"
fi

line=""
for segment in "$location" "$model" "${pct:+ctx $pct%}"; do
    [ -n "$segment" ] || continue
    line="${line:+$line · }$segment"
done
[ -n "$line" ] && printf '%s\n' "$line"
exit 0
