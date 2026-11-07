#!/usr/bin/env bash
# Install the offload host's sshd hardening drop-in, as root, for one work
# account (docs/offload-host.md).
#
# Usage: sudo offload-sshd-harden.sh <work-account>
#
# Run by an administrator from a checkout the administrator owns, never from
# the work account's own clone: root running a file that account can write
# would hand it root.
#
# Refuses unless the account's rendered authorized_keys.offload holds one
# readable from-restricted key, since closing password login without it would
# leave no way in over SSH. Validates the drop-in alone, installs it, then
# asserts sshd's effective config as a connection from the key's from= address
# gets it (Match blocks included). A drop-in this run installed is removed
# again if that fails; one an earlier run left is kept, so a failed re-run
# never re-opens password login.
#
# Prints OK when the installed drop-in already matches, CHANGED when it was
# installed or replaced, and exits non-zero with a FAILED: line otherwise.
#
# OFFLOAD_HARDEN_SSHD, OFFLOAD_HARDEN_CONF_D, OFFLOAD_HARDEN_HOMES and
# OFFLOAD_HARDEN_TEST exist for scripts/offload-sshd-harden-test.sh; sudo's
# env_reset keeps them out of a real run.

set -eu
umask 022

fail() {
  echo "FAILED: $*" >&2
  exit 1
}

[ "$#" -eq 1 ] || fail "usage: offload-sshd-harden.sh <work-account>"
user="$1"
case "$user" in
  '' | -* | *[!a-z0-9_.-]*) fail "the account name is not a plain macOS short name" ;;
esac

testing="${OFFLOAD_HARDEN_TEST:-}"
[ -n "$testing" ] || [ "$(id -u)" -eq 0 ] || fail "run it with sudo"

sshd="${OFFLOAD_HARDEN_SSHD:-/usr/sbin/sshd}"
conf_d="${OFFLOAD_HARDEN_CONF_D:-/etc/ssh/sshd_config.d}"
homes="${OFFLOAD_HARDEN_HOMES:-/Users}"

src_dir="$(CDPATH='' cd -P -- "$(dirname -- "$0")/../roles/osx/files/sshd" && pwd -P)" \
  || fail "could not find the drop-in beside this script's checkout"
name=050-dotfiles-hardening.conf
src="$src_dir/$name"
dest="$conf_d/$name"
[ -f "$src" ] && [ -r "$src" ] || fail "drop-in not readable: $src"
[ -d "$conf_d" ] || fail "$conf_d does not exist; this macOS has no sshd drop-in directory"

key="$homes/$user/.ssh/authorized_keys.offload"
[ ! -L "$key" ] || fail "$key is a symlink"
[ -f "$key" ] && [ -s "$key" ] || fail "$key is missing or empty; run the playbook as $user first"
keys="$(grep -cv '^[[:space:]]*\(#\|$\)' "$key" || true)"
[ "$keys" = 1 ] || fail "$key must hold exactly one key"
from="$(sed -n 's/^from="\([0-9.]*\)",restrict,pty ssh-ed25519 .*/\1/p' "$key")"
[ -n "$from" ] || fail "$key holds no from-restricted ed25519 key"
ssh-keygen -l -f "$key" >/dev/null 2>&1 || fail "ssh-keygen does not read $key"

if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
  existed=true changed=false
else
  [ -e "$dest" ] && existed=true || existed=false
  changed=true
  tmp="$(mktemp "$conf_d/.$name.XXXXXX")" || fail "could not create a temp file in $conf_d"
  cat "$src" >"$tmp" && chmod 0644 "$tmp" || { rm -f "$tmp"; fail "could not write $tmp"; }
  if [ -z "$testing" ]; then
    chown root:wheel "$tmp" || { rm -f "$tmp"; fail "could not chown $tmp"; }
  fi
  # The copy, not the source: it is the bytes sshd will read.
  "$sshd" -t -f "$tmp" || { rm -f "$tmp"; fail "sshd rejects the drop-in"; }
  mv -f "$tmp" "$dest" || { rm -f "$tmp"; fail "could not install $dest"; }
fi

undo() {
  if [ "$existed" = false ]; then
    rm -f "$dest"
    fail "$1; removed the drop-in this run installed"
  fi
  if [ "$changed" = true ]; then
    fail "$1; the drop-in this run installed replaced a differing one and was kept"
  fi
  fail "$1; the drop-in already in place was kept"
}

effective="$("$sshd" -T -C "user=$user,host=$from,addr=$from" 2>&1)" \
  || undo "sshd -T failed: $(printf '%s' "$effective" | head -n 1)"
for want in \
  'passwordauthentication no' \
  'kbdinteractiveauthentication no' \
  'pubkeyauthentication yes' \
  'permitrootlogin no' \
  'authorizedkeysfile .ssh/authorized_keys .ssh/authorized_keys.offload'; do
  printf '%s\n' "$effective" | grep -qxF -- "$want" \
    || undo "the effective config lacks '$want'; another drop-in or a Match block sets it first"
done

if [ "$changed" = true ]; then
  echo "CHANGED: installed $dest for $user from $from"
else
  echo "OK: $dest already installed and effective for $user from $from"
fi
