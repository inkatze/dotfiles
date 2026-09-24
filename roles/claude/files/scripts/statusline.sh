#!/usr/bin/env bash
# Claude Code status line: directory, git branch, model, context used.
# Reads the session JSON on stdin and prints one line; any field Claude Code
# omits or sends as null drops its segment.
set -uo pipefail

input=$(cat)

# The branch lookup gets the path exactly as sent: sanitizing it first, or
# letting $(...) eat a trailing newline, could point git at a neighbouring
# directory that the shortened name spells. The sentinel keeps the newline;
# a NUL cannot be in a real path and bash would drop it, so it is refused.
raw_dir=$(printf '%s' "$input" | jq -j '
  ((.workspace.current_dir // .cwd)
    | if type == "string" and (test("\u0000") | not) then . else "" end), "x"
' 2>/dev/null) || raw_dir=""
raw_dir=${raw_dir%x}

branch=""
if [ -n "$raw_dir" ]; then
    # The repository-locating variables a git hook exports (Claude started
    # from one inherits them) outrank -C.
    branch=$(
        unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR \
            GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
        git -C "$raw_dir" branch --show-current 2>/dev/null
    ) || branch=""
fi

# One jq pass for the display fields. The unit separator is not whitespace,
# so `read` keeps empty fields in place. Control, format (bidi overrides,
# zero-width joiners) and line-separator characters are stripped from every
# value, the branch included: a directory or branch name is attacker-choosable
# text from a cloned repo, and the line goes straight to the terminal.
fields=$(printf '%s' "$input" | jq -r --arg branch "$branch" '
  def text: if type == "string" then gsub("[\\p{Cc}\\p{Cf}\\p{Zl}\\p{Zp}]"; "") else "" end;
  [ ((.workspace.current_dir // .cwd) | text),
    ($branch | text),
    (.model.display_name | text),
    (.context_window.used_percentage
      | if type == "number" then floor | tostring else "" end)
  ] | join("\u001f")
' 2>/dev/null) || exit 0

IFS=$'\x1f' read -r dir branch model pct <<<"$fields"

location=""
if [ -n "$dir" ]; then
    location="${dir%/}"
    location="${location##*/}"
    location="${location:-/}"
    [ -n "$branch" ] && location="$location  $branch"
fi

line=""
for segment in "$location" "$model" "${pct:+ctx $pct%}"; do
    [ -n "$segment" ] || continue
    line="${line:+$line · }$segment"
done
[ -n "$line" ] && printf '%s\n' "$line"
exit 0
