#!/usr/bin/env bash
# Sync the GitHub Copilot MCP server registration in Claude Code with the
# GitHub PAT stored in 1Password. Idempotent: prints OK when the configured
# entry already matches the desired type/url/Authorization, CHANGED when it
# had to (re-)register, and exits non-zero with a FAILED: message on any
# precondition failure.
#
# The PAT is passed to jq via the GITHUB_PAT env var so it never lands in any
# subprocess argv (where `ps` could read it). The new ~/.claude.json is built
# in a temp file in the same directory and renamed into place, so a failure
# midway never leaves the user with no GitHub MCP entry at all.

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

pat=""
for field in credential password token; do
  if value=$(op item get "$ITEM_UUID" --fields "$field" --reveal 2>/dev/null); then
    if [ -n "$value" ]; then
      pat="$value"
      break
    fi
  fi
done

if [ -z "$pat" ]; then
  echo "FAILED: could not read GitHub PAT from 1Password item $ITEM_UUID (tried fields credential, password, token). Is op signed in?" >&2
  exit 1
fi

export GITHUB_PAT="$pat"

desired_entry=$(jq -nc \
  --arg type "$SERVER_TYPE" \
  --arg url "$SERVER_URL" \
  '{type: $type, url: $url, headers: {Authorization: ("Bearer " + env.GITHUB_PAT)}}')

current_entry="null"
if [ -f "$config" ]; then
  current_entry=$(jq -c --arg name "$SERVER_NAME" '.mcpServers[$name] // null' "$config" 2>/dev/null || echo "null")
fi

if [ "$current_entry" = "$desired_entry" ]; then
  echo "OK"
  exit 0
fi

mkdir -p "$(dirname "$config")"
tmp=$(mktemp "${config}.XXXXXX")
seed=""
trap 'rm -f "$tmp" "$seed"' EXIT

src="$config"
if [ ! -f "$config" ]; then
  seed="${tmp}.seed"
  printf '{}\n' > "$seed"
  src="$seed"
fi

jq \
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
  ' "$src" > "$tmp"

mv "$tmp" "$config"

if ! "$claude_bin" mcp get "$SERVER_NAME" >/dev/null 2>&1; then
  echo "FAILED: claude could not load $SERVER_NAME MCP entry after update" >&2
  exit 1
fi

echo "CHANGED"
