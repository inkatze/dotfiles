#!/usr/bin/env bash
# Sync one API key from a 1Password item's `credential` field (the API
# Credential category) into a machine-local file at 0600, for a tool that is
# handed the key at invocation rather than through the shell environment.
#
# Usage: op-key-sync.sh <item> <output>
#
# <item> is read from the vault DOTFILES_OP_VAULT names, through the shared
# service-account token helper. Prints OK when the file already holds the
# value, CHANGED when it is (re)written, and exits non-zero with a FAILED: line
# otherwise; Ansible gates changed_when on CHANGED.
#
# An existing key file that group or other can read is refused rather than
# tightened: the key may already have been read, so the fix is a rotation,
# which a chmod would hide.

set -eu
umask 077

fail() {
  echo "FAILED: $*" >&2
  exit 1
}

[ "$#" -eq 2 ] || fail "usage: op-key-sync.sh <item> <output>"
item="$1"
output="$2"

case "$item" in
  '' | -* | *[!A-Za-z0-9._\ -]*) fail "item name '$item' is outside [A-Za-z0-9._ -]" ;;
esac
case "$output" in
  /*) ;;
  *) fail "output must be an absolute path: $output" ;;
esac

mode_of() { stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null || echo ''; }

check_output() {
  if [ -L "$output" ]; then
    fail "refusing to write $output: it is a symlink"
  fi
  if [ -e "$output" ]; then
    [ -f "$output" ] || fail "refusing to write $output: not a regular file"
    perms="$(mode_of "$output")"
    case "$perms" in
      600 | 400) ;;
      '') fail "could not stat $output" ;;
      *) fail "$output is mode $perms, readable beyond its owner; rotate the key, remove the file, then re-run" ;;
    esac
  fi
  return 0
}
check_output

self="$0"
while [ -L "$self" ]; do
  link="$(readlink -- "$self")" || fail "could not resolve symlink $self"
  case "$link" in
    /*) self="$link" ;;
    *) self="$(dirname -- "$self")/$link" ;;
  esac
done
script_dir="$(CDPATH='' cd -P -- "$(dirname -- "$self")" && pwd -P)" \
  || fail "could not resolve the directory of $self"
[ -r "$script_dir/op-token.sh" ] || fail "helper not readable: $script_dir/op-token.sh"
# shellcheck source-path=SCRIPTDIR source=op-token.sh
. "$script_dir/op-token.sh"

# A service account cannot be granted the Personal or Private vault.
VAULT="${DOTFILES_OP_VAULT:-Dotfiles Service Account}"
resolve_op_token

command -v op >/dev/null 2>&1 || fail "1Password CLI (op) not installed"

if ! value="$(op_run item get "$item" --vault "$VAULT" --fields credential --reveal)"; then
  fail "op item get failed reading the credential field of item '$item' in vault '$VAULT'; see the op error above (locked session? missing item?)"
fi
is_blank "$value" && fail "item '$item' holds a blank credential field; set the key in 1Password"
case "$value" in
  *[[:space:]]*) fail "item '$item' holds a credential with a line break or space; an API key has none" ;;
esac

if [ -f "$output" ] && [ "$(cat "$output")" = "$value" ]; then
  echo "OK: $output already matches 1Password"
  exit 0
fi

out_dir="$(dirname -- "$output")"
mkdir -p -- "$out_dir" || fail "could not create $out_dir"
chmod 700 "$out_dir" 2>/dev/null || true

tmp_out=""
trap '[ -z "$tmp_out" ] || rm -f "$tmp_out"' EXIT
# Beside the output, so the rename is atomic; the umask above makes it 0600.
tmp_out="$(mktemp "$out_dir/.${output##*/}.XXXXXX")" || fail "could not create a temp file in $out_dir"
printf '%s' "$value" >"$tmp_out" || fail "could not write $tmp_out"
# Again, because the op call takes seconds.
check_output
mv -f -- "$tmp_out" "$output" || fail "could not move the key into $output"
tmp_out=""
echo "CHANGED: wrote $output from 1Password (item '$item')"
