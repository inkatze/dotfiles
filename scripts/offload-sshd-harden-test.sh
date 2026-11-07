#!/usr/bin/env bash
# Tests for scripts/offload-sshd-harden.sh. sshd is a stub on PATH-free argv
# (OFFLOAD_HARDEN_SSHD) and every directory is a throwaway one, so this runs
# anywhere, unprivileged, without touching the host's sshd.

set -eu

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
repo="$(CDPATH='' cd -- "$script_dir/.." && pwd)"
subject="$script_dir/offload-sshd-harden.sh"
dropin="$repo/roles/osx/files/sshd/050-dotfiles-hardening.conf"

pass=0
fail=0
ok() { echo "  ok: $1"; pass=$((pass + 1)); }
ko() { echo "  FAIL: $1"; fail=$((fail + 1)); }

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT

hardened='passwordauthentication no
kbdinteractiveauthentication no
pubkeyauthentication yes
permitrootlogin no
authorizedkeysfile .ssh/authorized_keys .ssh/authorized_keys.offload'

new_sandbox() {
  sandbox="$(mktemp -d "$root/case.XXXXXX")"
  mkdir -p "$sandbox/conf.d" "$sandbox/Users/fleet/.ssh"
  ssh-keygen -q -t ed25519 -N '' -f "$sandbox/k"
  printf '# rendered\nfrom="192.0.2.10",restrict,pty %s\n' "$(cat "$sandbox/k.pub")" \
    >"$sandbox/Users/fleet/.ssh/authorized_keys.offload"
  printf '%s\n' "$hardened" >"$sandbox/effective"
  : >"$sandbox/t-rc"
  cat >"$sandbox/sshd" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$STUB_DIR/argv"
case "$1" in
  -t) [ -s "$STUB_DIR/t-rc" ] && exit "$(cat "$STUB_DIR/t-rc")"; exit 0 ;;
  -T) cat "$STUB_DIR/effective" ;;
esac
FAKE
  chmod +x "$sandbox/sshd"
  export STUB_DIR="$sandbox" OFFLOAD_HARDEN_TEST=1 OFFLOAD_HARDEN_SSHD="$sandbox/sshd" \
    OFFLOAD_HARDEN_CONF_D="$sandbox/conf.d" OFFLOAD_HARDEN_HOMES="$sandbox/Users"
  dest="$sandbox/conf.d/050-dotfiles-hardening.conf"
}

run() {
  set +e
  log="$("$subject" "$@" 2>&1)"
  rc=$?
  set -e
}

expect_failed() { # expect_failed <label> <needle>
  if [ "$rc" -eq 0 ]; then ko "$1: exited 0 ($log)"
  elif ! grep -qF -- "$2" <<<"$log"; then ko "$1: expected \"$2\", got: $log"
  else ok "$1"; fi
}

echo "1. installs the tracked drop-in and checks it as the dispatching host's connection"
new_sandbox
run fleet
[ "$rc" -eq 0 ] && grep -q '^CHANGED:' <<<"$log" && ok "prints CHANGED" || ko "prints CHANGED ($log)"
cmp -s "$dropin" "$dest" && ok "the tracked drop-in is installed" || ko "the tracked drop-in is installed"
# World-readable, since the play's unprivileged checksum check reads it.
mode="$(stat -c '%a' "$dest" 2>/dev/null || stat -f '%Lp' "$dest")"
[ "$mode" = 644 ] && ok "installed at mode 0644" || ko "installed at mode $mode, not 0644"
grep -qxF -- "-T -C user=fleet,host=192.0.2.10,addr=192.0.2.10" "$sandbox/argv" \
  && ok "the effective config is read for the account from the from= address" || ko "sshd -T arguments ($(cat "$sandbox/argv"))"
grep -qxF -- "-t -f $dropin" "$sandbox/argv" && ok "the drop-in is validated alone first" || ko "sshd -t arguments"

echo "2. a re-run with nothing to change prints OK"
run fleet
[ "$rc" -eq 0 ] && grep -q '^OK:' <<<"$log" && ok "prints OK" || ko "prints OK ($log)"

echo "3. refuses before installing anything without one usable key"
new_sandbox
rm "$sandbox/Users/fleet/.ssh/authorized_keys.offload"
run fleet
expect_failed "a missing key file" "is missing or empty"
new_sandbox
printf 'from="192.0.2.10",restrict,pty %s\n' "$(cat "$sandbox/k.pub")" >>"$sandbox/Users/fleet/.ssh/authorized_keys.offload"
run fleet
expect_failed "two keys" "exactly one key"
new_sandbox
cat "$sandbox/k.pub" >"$sandbox/Users/fleet/.ssh/authorized_keys.offload"
run fleet
expect_failed "a key with no address pin" "no from-restricted ed25519 key"
new_sandbox
printf 'from="192.0.2.10",restrict,pty ssh-ed25519 AAAAnotakey\n' >"$sandbox/Users/fleet/.ssh/authorized_keys.offload"
run fleet
expect_failed "a key ssh-keygen cannot read" "ssh-keygen does not read"
[ -e "$dest" ] && ko "a refused run installed the drop-in" || ok "a refused run installs nothing"
new_sandbox
mv "$sandbox/Users/fleet/.ssh/authorized_keys.offload" "$sandbox/real-key"
ln -s "$sandbox/real-key" "$sandbox/Users/fleet/.ssh/authorized_keys.offload"
run fleet
expect_failed "a symlinked key file" "is a symlink"

echo "4. a drop-in sshd rejects is never installed"
new_sandbox
echo 255 >"$sandbox/t-rc"
run fleet
expect_failed "sshd -t failure" "sshd rejects"
[ -e "$dest" ] && ko "the rejected drop-in was installed" || ok "the rejected drop-in was not installed"

echo "5. an unhardened effective config undoes only this run"
new_sandbox
sed -i.bak 's/^passwordauthentication no$/passwordauthentication yes/' "$sandbox/effective"
run fleet
expect_failed "password login still effective" "lacks 'passwordauthentication no'"
[ -e "$dest" ] && ko "a fresh drop-in was left in place" || ok "a fresh drop-in is removed again"
new_sandbox
printf 'PasswordAuthentication no\n' >"$dest"
sed -i.bak '/^authorizedkeysfile /d' "$sandbox/effective"
run fleet
expect_failed "the offload key file not read" "lacks 'authorizedkeysfile"
[ -e "$dest" ] && ok "an earlier run's drop-in is kept" || ko "an earlier run's drop-in was removed"

echo "6. preconditions"
new_sandbox
run 'fleet;rm'
expect_failed "an account name outside the charset" "plain macOS short name"
run
expect_failed "no account" "usage"
if [ "$(id -u)" -ne 0 ]; then
  set +e
  log="$(env -u OFFLOAD_HARDEN_TEST "$subject" fleet 2>&1)"
  rc=$?
  set -e
  expect_failed "a run without root" "run it with sudo"
fi

echo
echo "offload-sshd-harden: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
