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
#
# This id is the item as it exists in the vault named below, and it is NOT the
# id the item had in the Private vault (that was hvscsuq25owvgrqt235xwlfmgy).
# 1Password assigns a fresh id when an item lands in a different vault, so the
# move that made this key reachable from a headless host also invalidated the
# old default.
#
# Both platforms now read this one item: a Mac's desktop-app session can see
# the service-account vault too. If a copy is still sitting in Private, it is
# no longer what anything reads, so delete it rather than leaving two items
# that can drift apart silently. On the first Mac run after this change the
# script will print CHANGED once as it rewrites the key file from the new
# item, then OK on every run after.
ITEM_UUID="${GEMINI_OP_ITEM_UUID:-kigewmgkgl4gct6qyeekbirn6q}"

# The vault holding that item. Named explicitly rather than left to op's
# search, because a service account REQUIRES one: called without --vault it
# refuses with "a vault query must be provided when this command is called by a
# service account" for every field, which reads like a missing-item error and
# is not. Same default vault as scripts/ssh-lan-config-sync.sh, and for the
# same reason recorded there: a service account cannot be granted the Personal
# or Private vault, so anything it must read lives here. Harmless on a Mac
# reading through the desktop app, which can see the vault too.
VAULT="${GEMINI_OP_VAULT:-${DOTFILES_OP_VAULT:-Dotfiles Service Account}}"

target="$HOME/.gemini/.api-key"

if ! command -v op >/dev/null 2>&1; then
  fail "1Password CLI (op) not installed"
fi

# Headless hosts have no 1Password desktop app to authorize against, so `op`
# fails with "connecting to desktop app: cannot connect to 1Password app"
# before it ever reads an item. Fall back to the machine-local service-account
# token, exactly as scripts/ssh-lan-config-sync.sh does and for the same
# reason: the desktop-app integration authorizes per calling process, which is
# useless under Ansible (a fresh process per task) and impossible during a
# headless boot.
#
# Note the vault consequence, because it constrains where the item may live: a
# service account cannot be granted access to the Personal or Private vault, so
# the Gemini API key has to sit in `Dotfiles Service Account` for this path to
# reach it. On a Mac with the desktop app running, the block below is skipped
# (no token file) and the item is read through the app session as before.
#
# An already-exported token wins, so CI or a caller can override without the
# file existing.
#
# `-s` rather than `-f`, because an EMPTY token file is worse than none: it
# passes a `-f` test and a mode check, and the resulting empty
# OP_SERVICE_ACCOUNT_TOKEN switches OFF the desktop-app path that would
# otherwise have worked, so a Mac fails with an error naming the item and the
# vault while the actual fault is a placeholder file. A `touch`ed file on the
# way to pasting a token is the ordinary way to reach that state.
OP_TOKEN_FILE="${DOTFILES_OP_TOKEN_FILE:-$HOME/.config/dotfiles/op-service-account-token}"
op_token=""
if [ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
  # A caller (CI, a wrapper shell, an Ansible environment) already supplied a
  # token. Take ownership of it and unset the exported copy, so `op_get` below
  # is the ONLY route by which it reaches a child process. Leaving it exported
  # would mean every later child -- including the `sh -c` that holds the
  # plaintext API key -- inherits the vault credential, which is exactly what
  # the scoping exists to prevent; the exported path would otherwise be the one
  # case where the guarantee quietly does not hold.
  op_token="$OP_SERVICE_ACCOUNT_TOKEN"
  unset OP_SERVICE_ACCOUNT_TOKEN
  # Same emptiness bar as the file path below. Validating one and not the other
  # was an asymmetry: a caller exporting a whitespace-only value would reach
  # `op` and come back with "failed to parseToken", the same misleading error
  # the file-side guard exists to prevent.
  if [ -z "$(printf '%s' "$op_token" | tr -d '[:space:]')" ]; then
    fail "OP_SERVICE_ACCOUNT_TOKEN is set but contains only whitespace; unset it or supply a real token"
  fi
elif [ -e "$OP_TOKEN_FILE" ]; then
  # `-e` above, then an explicit regular-file test: `-e` is what lets the empty
  # check below fire at all, but on its own it also captures a directory (a
  # `mkdir -p` typo on the parent path), which would otherwise reach the mode
  # check and fail with a confusing "is mode 755" instead of naming the real
  # problem.
  if [ ! -f "$OP_TOKEN_FILE" ]; then
    fail "$OP_TOKEN_FILE is not a regular file; remove it or replace it with the service-account token"
  fi
  if [ ! -s "$OP_TOKEN_FILE" ]; then
    fail "$OP_TOKEN_FILE exists but is empty; write the service-account token to it or remove it (an empty file disables the desktop-app fallback)"
  fi
  # Refuse a token file others can read: it is a bearer credential.
  perms="$(stat -c '%a' "$OP_TOKEN_FILE" 2>/dev/null || stat -f '%Lp' "$OP_TOKEN_FILE" 2>/dev/null || echo '')"
  case "$perms" in
    600 | 400) ;;
    '') fail "could not stat token file $OP_TOKEN_FILE" ;;
    *) fail "$OP_TOKEN_FILE is mode $perms; must be 600 or 400 (chmod 600 it)" ;;
  esac
  # Read through `fail()` rather than a bare assignment. Under `set -eu` an
  # unreadable file (mode 600 but owned by root, the state `sudo` leaves behind)
  # aborts on cat's own status, so the run ends with a raw "Permission denied"
  # and no `FAILED:` line -- breaking the contract this file's header states and
  # defeating any caller that greps for the prefix.
  op_token="$(cat "$OP_TOKEN_FILE" 2>/dev/null)" \
    || fail "$OP_TOKEN_FILE is not readable by this user (mode is $perms, but check the owner)"
  # Test a whitespace-stripped COPY, not the value itself. `$(...)` strips
  # trailing newlines and nothing else, so a file holding "   " or a tab yields
  # a non-empty op_token that sails past a bare `-z`, reaches `op`, and comes
  # back as "failed to parseToken, format is invalid" -- an error about the
  # token's shape, when the actual fault is a placeholder file. The real token
  # is passed through unmodified; only the emptiness test is normalised.
  if [ -z "$(printf '%s' "$op_token" | tr -d '[:space:]')" ]; then
    fail "$OP_TOKEN_FILE contains only whitespace; write the service-account token to it or remove it"
  fi
fi

# Run `op` with the service-account token scoped to the single call that needs
# it, instead of exporting it for the rest of the script. The header above
# promises the key is never on argv and that the env-var window stays narrow;
# a process-wide export contradicts the second half, since it would then be
# inherited by every later child -- mktemp, cat, chmod, mv, and the `sh -c`
# that holds the plaintext API key, which would carry BOTH secrets at once.
# Because the branch above unsets any inherited copy, this holds on the
# caller-supplied path too, not only when the token came from the file.
# Same-user inspection via /proc/<pid>/environ stays possible for the duration
# of an `op` call; that is the irreducible part.
op_get() {
  if [ -n "$op_token" ]; then
    OP_SERVICE_ACCOUNT_TOKEN="$op_token" op "$@"
  else
    op "$@"
  fi
}

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
# One stderr capture file for the whole loop, created BEFORE it and covered by
# a trap. Previously each iteration mktemp'd its own and removed it on the
# normal paths only, so an interrupt during any `op` call (the slow part, a
# network round trip) leaked one file per run with nothing to clean it up.
op_err=$(mktemp 2>&1) \
  || fail "could not create temp file for op stderr capture: $op_err"
trap 'rm -f "$op_err"' EXIT INT TERM HUP
for field in credential password api_key apikey; do
  : > "$op_err"
  if value=$(op_get item get "$ITEM_UUID" --vault "$VAULT" --fields "$field" --reveal 2>"$op_err"); then
    if [ -n "$value" ]; then
      new_key="$value"
      break
    fi
  fi
  err=$(cat "$op_err")
  if [ -n "$err" ]; then
    op_errors="${op_errors}  [$field] $err"$'\n'
  fi
done
rm -f "$op_err"
trap - EXIT INT TERM HUP

if [ -z "$new_key" ]; then
  echo "FAILED: could not read Gemini API key from 1Password item $ITEM_UUID in vault '$VAULT' (tried fields credential, password, api_key, apikey). Is op signed in? On a headless host that means a readable $OP_TOKEN_FILE whose service account can reach that vault (service accounts cannot be granted Personal or Private)." >&2
  if [ -n "$op_errors" ]; then
    printf 'op errors:\n%s' "$op_errors" >&2
  fi
  exit 1
fi

# Fast path: if the on-disk key already matches, exit OK without rewriting.
#
# The mode is still asserted before the early exit. chmod 600 otherwise only
# ever runs on the slow path (against the temp file), so a key file that
# already holds the right bytes at the wrong mode would stay loose forever:
# no future run rewrites it, because the content matches. That state is
# reachable rather than theoretical -- the Linux host carried a fish snippet
# reading this path long before anything wrote it, so a hand-created
# `echo ... > ~/.gemini/.api-key` at a default umask lands exactly there. The
# gemini CLI also creates ~/.gemini itself at 0755, so the directory is not
# reliably a second line of defence.
if [ -f "$target" ]; then
  current_key=$(cat "$target" 2>/dev/null) \
    || fail "$target exists but is not readable; inspect it manually"
  if [ "$current_key" = "$new_key" ]; then
    # Only chmod when the mode is actually wrong. An unconditional chmod would
    # turn the steady state into a hard failure on a host where the key file is
    # owned by someone else (root, if it was ever created under sudo): the
    # content matches, so the old code printed OK, and an EPERM here would fail
    # the Ansible task and abort the last role in main.yml on EVERY run --
    # re-entering, through a different door, the exact failure the `op` probe
    # was added to prevent.
    target_perms="$(stat -c '%a' "$target" 2>/dev/null || stat -f '%Lp' "$target" 2>/dev/null || echo '')"
    if [ "$target_perms" != "600" ]; then
      chmod 600 "$target" \
        || fail "$target is mode ${target_perms:-unknown} and could not be tightened to 600; check its owner"
    fi
    # Same treatment for the directory, for the reason the slow path's chmod
    # records: the gemini CLI creates ~/.gemini itself at 0755, and on a
    # converged host the slow path never runs again to correct it.
    dir_perms="$(stat -c '%a' "$(dirname "$target")" 2>/dev/null || stat -f '%Lp' "$(dirname "$target")" 2>/dev/null || echo '')"
    if [ "$dir_perms" != "700" ]; then
      chmod 700 "$(dirname "$target")" 2>/dev/null || true
    fi
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

# INT/TERM/HUP as well as EXIT: the temp file holds the plaintext API key
# between the write and the rename, and a Ctrl-C or an Ansible timeout in that
# window would otherwise leave ~/.gemini/.api-key.XXXXXX on disk forever. The
# fast path never looks at those names, so nothing would ever clean them up.
trap 'rm -f "$tmp"' EXIT INT TERM HUP

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
