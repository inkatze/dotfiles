#!/usr/bin/env bash
# Sync the GitHub Copilot MCP server registration in Claude Code with the
# GitHub PAT stored in 1Password. Idempotent: prints OK when the configured
# entry already matches the desired type/url/Authorization, CHANGED when it
# had to (re-)register, and exits non-zero with a FAILED: message on any
# precondition failure.
#
# The PAT is passed to jq via the GITHUB_PAT env var (never on argv where `ps`
# could read it) and is scoped to the jq invocations only — the `claude mcp
# get` sanity check at the end does not inherit it. The new ~/.claude.json is
# built in a temp file in the same directory and renamed into place; a backup
# of the previous file is kept so a failed sanity check rolls back instead of
# leaving the user with a broken or missing MCP entry.

set -eu

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

# Validate the existing config before we read or rewrite it. Without this, a
# malformed file (or a non-object .mcpServers) would propagate raw `jq` parse
# errors instead of the FAILED:-prefixed contract this script promises.
if [ -f "$config" ]; then
  if ! jq empty "$config" >/dev/null 2>&1; then
    echo "FAILED: $config is not valid JSON; refusing to overwrite. Inspect and repair manually." >&2
    exit 1
  fi
  servers_type=$(jq -r '.mcpServers | type' "$config")
  case "$servers_type" in
    object|null) ;;
    *)
      echo "FAILED: $config has .mcpServers of type $servers_type, expected object. Inspect and repair manually." >&2
      exit 1
      ;;
  esac
fi

pat=""
op_errors=""
for field in token credential; do
  op_err=$(mktemp)
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
if [ -f "$config" ]; then
  current_entry=$(jq -c --arg name "$SERVER_NAME" '.mcpServers[$name] // null' "$config")
fi

if [ "$current_entry" = "$desired_entry" ]; then
  echo "OK"
  exit 0
fi

mkdir -p "$(dirname "$config")"
tmp=$(mktemp "${config}.XXXXXX")
seed=""
backup=""
jq_err=""
trap 'rm -f "$tmp" "$seed" "$backup" "$jq_err"' EXIT

src="$config"
if [ ! -f "$config" ]; then
  seed="${tmp}.seed"
  printf '{}\n' > "$seed"
  src="$seed"
fi

jq_err=$(mktemp)
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
  echo "FAILED: jq could not update $config: $(cat "$jq_err")" >&2
  exit 1
fi

# Backup the previous config in the same directory (so the rollback `mv` is
# atomic on the same filesystem) before swapping in the new file.
if [ -f "$config" ]; then
  backup=$(mktemp "${config}.bak.XXXXXX")
  cp -p "$config" "$backup"
fi

mv "$tmp" "$config"

if ! "$claude_bin" mcp get "$SERVER_NAME" >/dev/null 2>&1; then
  if [ -n "$backup" ]; then
    mv "$backup" "$config"
    backup=""
    echo "FAILED: claude could not load $SERVER_NAME MCP entry after update; restored previous $config" >&2
  else
    rm -f "$config"
    echo "FAILED: claude could not load $SERVER_NAME MCP entry after update; no prior config to restore" >&2
  fi
  exit 1
fi

echo "CHANGED"
