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

raw_branch=""
if [ -n "$raw_dir" ]; then
    # The repository-locating variables a git hook exports (Claude started
    # from one inherits them) outrank -C.
    raw_branch=$(
        unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR \
            GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES
        git -C "$raw_dir" branch --show-current 2>/dev/null
    ) || raw_branch=""
fi

# One jq pass for the display fields. The unit separator is not whitespace,
# so `read` keeps empty fields in place. Control, format (bidi overrides,
# zero-width joiners) and line- and paragraph-separator characters are
# stripped from every value, the branch included: a directory or branch name
# is attacker-choosable text from a cloned repo, and the line goes straight
# to the terminal. The directory is cut to its last component before that
# strip, so a name made only of stripped characters vanishes instead of
# turning into its parent's. The rate limits ride along unstripped, as JSON
# for the mirror below, never for the terminal.
fields=$(printf '%s' "$input" | jq -r --arg branch "$raw_branch" '
  def sanitized: if type == "string" then gsub("[\\p{Cc}\\p{Cf}\\p{Zl}\\p{Zp}]"; "") else "" end;
  def basename: if type != "string" or . == "" then ""
    else (sub("/+$"; "") | if . == "" then "/" else split("/") | last end) end;
  [ ((.workspace.current_dir // .cwd) | basename | sanitized),
    ($branch | sanitized),
    (.model.display_name | sanitized),
    (.context_window.used_percentage
      | if type == "number" then floor | tostring else "" end),
    (.rate_limits | if type == "object" then tojson else "" end)
  ] | join("\u001f")
' 2>/dev/null) || exit 0

IFS=$'\x1f' read -r dir branch model pct limits <<<"$fields"

# Mirror the account's rate-limit windows for tools that pace on usage (the
# fleet and mission control). It rides the display pass rather than its own
# jq, which would cost the line a process start on every refresh. tojson
# escapes every control character, so the field cannot split the read. The
# stderr redirect wraps the group because a failed `>` reports before any
# redirect on its own command applies; the rename keeps readers off a
# half-written file.
rl_cache=${XDG_CACHE_HOME:-${HOME:+$HOME/.cache}}
if [ -n "$limits" ] && [ -n "$rl_cache" ]; then
    rl_dir="$rl_cache/claude-usage"
    {
        if ! { { [ -d "$rl_dir" ] || mkdir -p "$rl_dir"; } &&
            printf '%s\n' "$limits" >"$rl_dir/.rl.$$" &&
            mv -f "$rl_dir/.rl.$$" "$rl_dir/rate-limits.json"; }; then
            rm -f "$rl_dir/.rl.$$"
        fi
    } 2>/dev/null
fi

location=""
if [ -n "$dir" ]; then
    location="$dir"
    [ -n "$branch" ] && location="$location  $branch"
fi

line=""
for segment in "$location" "$model" "${pct:+ctx $pct%}"; do
    [ -n "$segment" ] || continue
    line="${line:+$line · }$segment"
done
[ -n "$line" ] && printf '%s\n' "$line"
exit 0
