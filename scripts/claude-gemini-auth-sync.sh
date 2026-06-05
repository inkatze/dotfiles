#!/usr/bin/env bash
# Sync the Gemini API key from 1Password into ~/.gemini/.api-key, where
# fish conf.d/gemini.fish picks it up and exports GEMINI_API_KEY into the
# shell environment so the gemini CLI can authenticate non-interactively.
#
# Idempotent: prints OK when the on-disk key already matches the 1Password
# value, CHANGED when the file is (re-)written, and exits non-zero with a
# FAILED: message on any precondition failure (op not installed, 1Password
# item not readable, target path looks suspicious, etc.).
#
# The key is passed through env vars only, never argv (which `ps -A` would
# expose to other users on the box). Same-user inspection via
# `ps eww <pid>` or /proc/<pid>/environ remains possible; scoping the env
# var to the single write call narrows that window.
#
# Auth path: GEMINI_API_KEY env var. The gemini CLI accepts an API key from
# this env var even without ~/.gemini/settings.json, which is why the
# write target is a simple key file (not a settings.json rewrite). If a
# settings.json exists with selectedAuthType=USE_GEMINI the env var still
# wins; with a different selectedAuthType the env var is ignored. Users on
# OAuth (LOGIN_WITH_GOOGLE_PERSONAL) who want to switch to the API key
# should remove ~/.gemini/settings.json or set selectedAuthType=USE_GEMINI.

set -eu

fail() {
  echo "FAILED: $*" >&2
  exit 1
}

# Defaults to the Gemini API-key 1Password item; override with
# GEMINI_OP_ITEM_UUID if the item lives under a different id on a given host.
# If the item cannot be read, the script fails loudly (see below) so an
# uninitialized deployment cannot silently skip the sync.
ITEM_UUID="${GEMINI_OP_ITEM_UUID:-hvscsuq25owvgrqt235xwlfmgy}"

target="$HOME/.gemini/.api-key"

if ! command -v op >/dev/null 2>&1; then
  fail "1Password CLI (op) not installed"
fi

# Refuse to overwrite anything that is not a plain regular file. Symlinks
# and special files signal another tool is managing this path; rewriting
# would silently decouple their management.
if [ -L "$target" ]; then
  fail "$target is a symlink (target: $(readlink "$target")); refusing to overwrite. Resolve manually."
fi
if [ -e "$target" ] && [ ! -f "$target" ]; then
  fail "$target exists but is not a regular file; refusing to overwrite. Inspect and clean up manually."
fi

# Read from 1Password. Try `credential` first (API Credential category),
# then `password` (Login or Password category). The Gemini API key is not
# a login password (it is a token issued by AI Studio), so the
# `password` field is a legitimate fallback here (unlike the GitHub PAT
# script where `password` would resolve to the account login password).
new_key=""
op_errors=""
for field in credential password api_key apikey; do
  op_err=$(mktemp 2>&1) \
    || fail "could not create temp file for op stderr capture: $op_err"
  if value=$(op item get "$ITEM_UUID" --fields "$field" --reveal 2>"$op_err"); then
    if [ -n "$value" ]; then
      new_key="$value"
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

if [ -z "$new_key" ]; then
  echo "FAILED: could not read Gemini API key from 1Password item $ITEM_UUID (tried fields credential, password, api_key, apikey). Is op signed in?" >&2
  if [ -n "$op_errors" ]; then
    printf 'op errors:\n%s' "$op_errors" >&2
  fi
  exit 1
fi

# Fast path: if the on-disk key already matches, exit OK without rewriting.
if [ -f "$target" ]; then
  current_key=$(cat "$target")
  if [ "$current_key" = "$new_key" ]; then
    echo "OK"
    exit 0
  fi
fi

# Slow path: write atomically via temp + rename so a crash mid-write
# leaves either the old key or the new key, never a truncated file.
target_dir=$(dirname "$target")
mkdir_err=$(mkdir -p "$target_dir" 2>&1) \
  || fail "could not create config directory $target_dir: $mkdir_err"
# Best-effort: tighten the dir holding the API key, matching the Ansible file
# task's 0700 (defense-in-depth for when the script runs before Ansible or is
# invoked directly). No hard fail; the key file itself is chmod 600 below.
chmod 700 "$target_dir" 2>/dev/null || true

tmp=$(mktemp "${target}.XXXXXX" 2>&1) \
  || fail "could not create temp file next to $target: $tmp"

trap 'rm -f "$tmp"' EXIT

# Write the key via printf with the value sourced from an env var; this
# avoids putting the key on argv (where `ps -A` could leak it) without
# touching disk twice. Use printf '%s' (not printf "$value") to avoid
# format-string interpretation of any % in the key.
if ! GEMINI_API_KEY="$new_key" sh -c 'printf "%s" "$GEMINI_API_KEY"' > "$tmp"; then
  fail "could not write key to temp file $tmp"
fi

chmod 600 "$tmp" || fail "could not chmod 600 $tmp"

if ! mv "$tmp" "$target"; then
  fail "could not move temp file into place at $target"
fi
trap - EXIT

echo "CHANGED"
