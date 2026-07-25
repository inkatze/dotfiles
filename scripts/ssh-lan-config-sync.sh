#!/usr/bin/env bash
# Render the LAN ssh host aliases from 1Password into ~/.ssh/config.local,
# which roles/ssh/files/config pulls in via `Include ~/.ssh/config.local`.
#
# Why this exists: specs/linux-migration REQ-F1.1 keeps LAN topology (internal
# hostnames, RFC1918 addresses) out of this public repo, but the aliases still
# have to reach every host — and a gitignored file does not sync. So the
# structure lives in a committed template (roles/ssh/files/config.lan.tpl) with
# `op://` secret references, and only the values live in 1Password. This is
# 1Password's own mechanism: `op inject` resolves the references at run time.
#
# Idempotent: prints OK when the rendered output already matches what is on
# disk, CHANGED when the file is (re-)written, and exits non-zero with a
# FAILED: line on any precondition failure. Ansible gates changed_when on
# CHANGED, so a rotation shows up as a single changed step.
#
# Secret handling: the rendered config never passes through argv (`ps -A -o
# args=` is world-readable). It is written by `op inject --out-file` straight
# to a temp file with mode 0600, then atomically renamed into place.
#
# The 1Password item must carry these fields (see roles/ssh/README.md):
#   server_alias  the short ssh alias, e.g. the host's name
#   server_host   the resolvable hostname, e.g. <alias>.local
#   server_ip     the LAN address
#   server_user   the login user

set -eu

fail() {
  echo "FAILED: $*" >&2
  exit 1
}

# Not Private. 1Password refuses to grant a service account access to the
# Personal/Private vault at all ("You can't grant a service account access to
# your Personal or Private vault"), so the item lives in a vault that can be
# shared with one.
VAULT="${DOTFILES_OP_VAULT:-Dotfiles Service Account}"
ITEM="${DOTFILES_OP_ITEM:-dotfiles-lan-ssh}"

# Prefer a service-account token over the desktop-app integration.
#
# The desktop path authorizes per calling process and re-prompts for each new
# one. That is fine in a long-lived terminal and useless under Ansible, which
# spawns a fresh process per task -- and impossible during Task 10's headless
# boot test, where no desktop app is running to approve anything. A service
# account token authenticates non-interactively and headlessly.
#
# The token is machine-local and gitignored, alongside the other files in
# ~/.config/dotfiles/ (see CLAUDE.md). An already-exported token wins, so CI or
# a caller can override without touching the file.
OP_TOKEN_FILE="${DOTFILES_OP_TOKEN_FILE:-$HOME/.config/dotfiles/op-service-account-token}"
if [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && [ -f "$OP_TOKEN_FILE" ]; then
  # Refuse a token file others can read: it is a bearer credential.
  perms="$(stat -c '%a' "$OP_TOKEN_FILE" 2>/dev/null || stat -f '%Lp' "$OP_TOKEN_FILE" 2>/dev/null || echo '')"
  case "$perms" in
    600 | 400) ;;
    '') fail "could not stat token file $OP_TOKEN_FILE" ;;
    *) fail "$OP_TOKEN_FILE is mode $perms; must be 600 or 400 (chmod 600 it)" ;;
  esac
  OP_SERVICE_ACCOUNT_TOKEN="$(cat "$OP_TOKEN_FILE")"
  export OP_SERVICE_ACCOUNT_TOKEN
fi

# Resolve the template relative to this script so the caller's cwd does not
# matter (Ansible invokes it with ansible_env.PWD, a human may not).
script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
template="$script_dir/../roles/ssh/files/config.lan.tpl"
target="$HOME/.ssh/config.local"

[ -r "$template" ] || fail "template not readable: $template"

command -v op >/dev/null 2>&1 || fail "1Password CLI (op) not installed"

# Refuse to overwrite anything that is not a plain regular file. A symlink or
# special file means something else manages this path; rewriting would
# silently decouple that tool's management.
if [ -e "$target" ] || [ -L "$target" ]; then
  [ -L "$target" ] && fail "refusing to write $target: it is a symlink"
  [ -f "$target" ] || fail "refusing to write $target: not a regular file"
fi

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

tmp_tpl="$(mktemp)"
tmp_out="$(mktemp)"
cleanup() { rm -f "$tmp_tpl" "$tmp_out"; }
trap cleanup EXIT

# Point the template's references at the configured vault/item. Both are
# names, not secrets, so this substitution is safe to do in the clear.
sed -e "s|__OP_VAULT__|$VAULT|g" -e "s|__OP_ITEM__|$ITEM|g" \
  "$template" >"$tmp_tpl" || fail "could not prepare template"

# --force: never prompt (this runs unattended under Ansible).
# --file-mode 0600: ssh refuses a group/world-readable config.
# stdout is redirected because `op inject --out-file` echoes the path it wrote,
# which would otherwise land in the stdout Ansible registers and greps for the
# OK:/CHANGED: markers.
#
# stderr is NOT swallowed. It used to be, and that cost real debugging time:
# every failure surfaced as the generic message below regardless of cause, so a
# malformed template and a dismissed auth prompt looked identical. op's own
# error line is the useful part -- pass it through and keep the hint as context.
if ! op inject --force --file-mode 0600 --in-file "$tmp_tpl" --out-file "$tmp_out" >/dev/null; then
  fail "op inject failed reading vault='$VAULT' item='$ITEM' — see the op error above (locked session? missing item? bad field name?)"
fi

# op's exit status has not always distinguished an unresolved reference from a
# clean run, so verify the rendered output directly: no leftover references, no
# leftover placeholders, and non-trivial content.
#
# Two distinct checks, because the template's own comments legitimately mention
# `op://` when explaining itself: a surviving `{{` means inject did not
# substitute at all, and an `op://` on a *non-comment* line means a reference
# leaked into real config. Checking bare `op://` everywhere would flag the
# documentation.
if grep -q '{{' "$tmp_out"; then
  fail "unsubstituted template expression left in rendered config — check the item's field names"
fi
if grep -v '^[[:space:]]*#' "$tmp_out" | grep -q 'op://'; then
  fail "unresolved secret reference left in rendered config — check the item's field names"
fi
if grep -q '__OP_VAULT__\|__OP_ITEM__' "$tmp_out"; then
  fail "template placeholder survived substitution"
fi
if ! grep -q '^[[:space:]]*Host[[:space:]]' "$tmp_out"; then
  fail "rendered config contains no Host block — refusing to install it"
fi

# A malformed render would break every ssh call on this host, so parse it
# before installing. -G resolves the config without connecting anywhere.
if ! ssh -F "$tmp_out" -G example.com >/dev/null 2>"$tmp_tpl"; then
  fail "rendered config does not parse: $(head -1 "$tmp_tpl")"
fi

if [ -f "$target" ] && cmp -s "$tmp_out" "$target"; then
  echo "OK: $target already matches 1Password"
  exit 0
fi

chmod 600 "$tmp_out"
mv -f "$tmp_out" "$target"
# mv consumed the temp file; keep cleanup from reporting on it.
tmp_out="$(mktemp)"
echo "CHANGED: rewrote $target from 1Password (vault='$VAULT' item='$ITEM')"
