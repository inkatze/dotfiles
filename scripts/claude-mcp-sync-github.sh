#!/usr/bin/env bash
# Sync the GitHub Copilot MCP server registration in Claude Code with the
# GitHub PAT stored in 1Password. Idempotent: prints OK when the configured
# entry matches the desired type/url/Authorization AND `claude mcp get`
# confirms it is loadable, CHANGED when it had to (re-)register, and exits
# non-zero with a FAILED: message on any precondition failure (including a
# matching-but-unloadable entry caused by drift elsewhere in the file).
#
# The PAT is passed to jq via the GITHUB_PAT env var (never on argv where `ps`
# could read it) and is scoped to the jq invocations only — the `claude mcp
# get` sanity check at the end does not inherit it. The new ~/.claude.json is
# built in a temp file in the same directory and renamed into place. When a
# previous ~/.claude.json existed it is backed up first and restored if the
# sanity check fails; on a first-time registration there is nothing to roll
# back to, so a failed sanity check removes the partially-written file and
# exits FAILED: with a "no prior config to restore" message, leaving the
# machine in its pre-run state.

set -eu

fail() {
  echo "FAILED: $*" >&2
  exit 1
}

ITEM_UUID="co7bb5b6pfej3lhfni4skvonki"
SERVER_NAME="github"
SERVER_URL="https://api.githubcopilot.com/mcp"
SERVER_TYPE="http"

claude_bin="${CLAUDE_BIN:-$HOME/.local/bin/claude}"
config="$HOME/.claude.json"

if ! command -v op >/dev/null 2>&1; then
  echo "FAILED: 1Password CLI (op) not installed" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "FAILED: jq not installed" >&2
  exit 1
fi

if [ ! -x "$claude_bin" ]; then
  echo "FAILED: claude CLI not found at $claude_bin" >&2
  exit 1
fi

# Refuse to overwrite anything that isn't a plain regular file. This script
# writes via mv-into-place, which would (a) silently replace a symlink with
# a regular file and decouple another dotfiles repo's management from the
# result, or (b) move the temp file *inside* the path if it is a directory,
# leaving stray state with no clean rollback. `[ -L ]` is checked first so
# `[ -e ]` (which follows symlinks) does not classify a dangling symlink as
# nonexistent.
if [ -L "$config" ]; then
  fail "$config is a symlink (target: $(readlink "$config")); refusing to overwrite. Resolve by removing the symlink (this script will regenerate the file) or by having your dotfiles repo manage the github MCP entry directly."
fi
if [ -e "$config" ] && [ ! -f "$config" ]; then
  fail "$config exists but is not a regular file (likely a directory or special file); refusing to overwrite. Inspect and clean up manually."
fi

# Validate the existing config before we read or rewrite it. Distinguish
# unreadable-file from invalid-JSON so a permissions issue does not get
# reported as JSON corruption; otherwise a `jq empty` failure would swallow
# permission errors and steer the user toward repairing valid content.
if [ -f "$config" ]; then
  if [ ! -r "$config" ]; then
    fail "$config is not readable (permission issue?). Inspect ownership/perms."
  fi
  if ! jq empty "$config" >/dev/null 2>&1; then
    fail "$config is not valid JSON; refusing to overwrite. Inspect and repair manually."
  fi
  root_type=$(jq -r 'type' "$config")
  if [ "$root_type" != "object" ]; then
    fail "$config root is of type $root_type, expected object. Inspect and repair manually."
  fi
  servers_type=$(jq -r '(.mcpServers // null) | type' "$config")
  case "$servers_type" in
    object|null) ;;
    *)
      fail "$config has .mcpServers of type $servers_type, expected object. Inspect and repair manually."
      ;;
  esac
fi

# Snapshot $config's starting state BEFORE any potentially-slow step (op
# fetch, jq write) so the pre-mv recheck can detect modifications or
# creations that happened during the run. Captured here, after pre-
# validation, so we can canonicalize on the JSON we have already proved
# to be a parseable object. config_existed plus config_snapshot together
# encode the starting state: existed-and-content-was-X, or did-not-exist.
config_existed=false
config_snapshot=""
if [ -f "$config" ]; then
  config_existed=true
  config_snapshot=$(jq -cS '.' "$config")
fi

pat=""
op_errors=""
for field in token credential; do
  op_err=$(mktemp 2>&1) \
    || fail "could not create temp file for op stderr capture: $op_err"
  if value=$(op item get "$ITEM_UUID" --fields "$field" --reveal 2>"$op_err"); then
    if [ -n "$value" ]; then
      pat="$value"
      rm -f "$op_err"
      break
    fi
  fi
  err=$(cat "$op_err")
  rm -f "$op_err"
  if [ -n "$err" ]; then
    op_errors="${op_errors}  [$field] $err"$'\n'
  fi
done

# `password` is intentionally NOT a fallback: on a LOGIN-category item it
# resolves to the GitHub account password, which would be sent as a Bearer
# token to api.githubcopilot.com — exactly the bug that motivated this guard.
if [ -z "$pat" ]; then
  echo "FAILED: could not read GitHub PAT from 1Password item $ITEM_UUID (tried fields token, credential). Is op signed in?" >&2
  if [ -n "$op_errors" ]; then
    printf 'op errors:\n%s' "$op_errors" >&2
  fi
  exit 1
fi

desired_entry=$(GITHUB_PAT="$pat" jq -nc \
  --arg type "$SERVER_TYPE" \
  --arg url "$SERVER_URL" \
  '{type: $type, url: $url, headers: {Authorization: ("Bearer " + env.GITHUB_PAT)}}')

current_entry="null"
if $config_existed; then
  # Reuse the canonical snapshot captured before the op loop; equivalent to
  # `jq -c '.mcpServers[$name] // null' "$config"` on the original content.
  current_entry=$(jq -c --arg name "$SERVER_NAME" '.mcpServers[$name] // null' <<<"$config_snapshot")
fi

# Structural compare so a hand-edited or tool-written entry with the same
# values but different JSON key order is still treated as OK rather than
# pointlessly rewritten. Even when the entry already matches, run the same
# `claude mcp get` sanity check the write path runs — otherwise a matching
# entry could sit on disk while drift in some other top-level field makes
# claude refuse to load the file, and we'd silently report OK.
if jq -ne \
  --argjson a "$current_entry" \
  --argjson b "$desired_entry" \
  '$a == $b' >/dev/null 2>&1; then
  if "$claude_bin" mcp get "$SERVER_NAME" >/dev/null 2>&1; then
    echo "OK"
    exit 0
  fi
  fail "$config already declares the desired $SERVER_NAME entry but '$claude_bin mcp get $SERVER_NAME' could not load it. Inspect the file for drift in another top-level field."
fi

config_dir=$(dirname "$config")
mkdir_err=$(mkdir -p "$config_dir" 2>&1) \
  || fail "could not create config directory $config_dir: $mkdir_err"

tmp=$(mktemp "${config}.XXXXXX" 2>&1) \
  || fail "could not create temp file next to $config: $tmp"

seed=""
backup=""
jq_err=""
trap 'rm -f "$tmp" "$seed" "$backup" "$jq_err"' EXIT

src="$config"
if [ ! -f "$config" ]; then
  seed="${tmp}.seed"
  seed_err=$({ printf '{}\n' > "$seed"; } 2>&1) \
    || fail "could not write seed file $seed: $seed_err"
  src="$seed"
fi

jq_err=$(mktemp 2>&1) \
  || fail "could not create jq error capture file: $jq_err"

if ! GITHUB_PAT="$pat" jq \
  --arg name "$SERVER_NAME" \
  --arg type "$SERVER_TYPE" \
  --arg url "$SERVER_URL" \
  '
    .mcpServers //= {}
    | .mcpServers[$name] = {
        type: $type,
        url: $url,
        headers: {Authorization: ("Bearer " + env.GITHUB_PAT)}
      }
  ' "$src" > "$tmp" 2>"$jq_err"; then
  fail "jq could not update $config: $(cat "$jq_err")"
fi

# Backup the previous config in the same directory (so the rollback `mv` is
# atomic on the same filesystem) before swapping in the new file.
if [ -f "$config" ]; then
  backup=$(mktemp "${config}.bak.XXXXXX" 2>&1) \
    || fail "could not create backup file next to $config: $backup"
  cp_err=$(cp -p "$config" "$backup" 2>&1) \
    || fail "could not back up $config to $backup: $cp_err"
fi

# Re-check $config and abort if a concurrent writer modified or created it
# between the initial read and now. Pre-existing file: full-snapshot diff.
# First-time registration: assert the file still doesn't exist (a concurrent
# creator would have content we'd otherwise clobber).
if $config_existed; then
  current_snapshot=$(jq -cS '.' "$config" 2>/dev/null) || current_snapshot=""
  if [ "$current_snapshot" != "$config_snapshot" ]; then
    fail "$config was modified by another process during this run; refusing to overwrite to avoid clobbering concurrent writes. Re-run the task."
  fi
elif [ -e "$config" ] || [ -L "$config" ]; then
  fail "$config did not exist when this run started but does now; another process appears to have created it concurrently. Refusing to overwrite. Re-run the task."
fi

mv_err=$(mv "$tmp" "$config" 2>&1) \
  || fail "could not move new config into place at $config: $mv_err"

if ! "$claude_bin" mcp get "$SERVER_NAME" >/dev/null 2>&1; then
  if [ -n "$backup" ]; then
    if rb_err=$(mv "$backup" "$config" 2>&1); then
      backup=""
      fail "claude could not load $SERVER_NAME MCP entry after update; restored previous $config"
    else
      preserved="$backup"
      backup=""  # keep the file on disk for manual recovery; trap must not rm it
      fail "claude could not load $SERVER_NAME MCP entry after update; rollback also failed ($rb_err); previous config preserved at $preserved"
    fi
  else
    rm -f "$config" 2>/dev/null || true
    fail "claude could not load $SERVER_NAME MCP entry after update; no prior config to restore"
  fi
fi

echo "CHANGED"
