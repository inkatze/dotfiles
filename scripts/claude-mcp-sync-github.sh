#!/usr/bin/env bash
# Sync the GitHub Copilot MCP server registration in Claude Code with the
# GitHub PAT stored in 1Password. Idempotent: prints OK when the configured
# token already matches, CHANGED when it had to (re-)register, and exits
# non-zero with a FAILED: message on any precondition failure.

set -eu

ITEM_UUID="co7bb5b6pfej3lhfni4skvonki"
SERVER_NAME="github"
SERVER_URL="https://api.githubcopilot.com/mcp"

claude_bin="${CLAUDE_BIN:-$HOME/.local/bin/claude}"
config="$HOME/.claude.json"

if ! command -v op >/dev/null 2>&1; then
  echo "FAILED: 1Password CLI (op) not installed" >&2
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

current=""
if [ -f "$config" ]; then
  current=$(jq -r --arg name "$SERVER_NAME" '.mcpServers[$name].headers.Authorization // ""' "$config" 2>/dev/null || true)
fi

if [ "$current" = "Bearer $pat" ]; then
  echo "OK"
  exit 0
fi

"$claude_bin" mcp remove "$SERVER_NAME" --scope user >/dev/null 2>&1 || true
desired=$(printf '{"type":"http","url":"%s","headers":{"Authorization":"Bearer %s"}}' "$SERVER_URL" "$pat")
"$claude_bin" mcp add-json "$SERVER_NAME" "$desired" --scope user >/dev/null
echo "CHANGED"
