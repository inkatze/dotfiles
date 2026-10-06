#!/usr/bin/env bash
# Tests for scripts/op-key-sync.sh.
#
# 1Password is stubbed with a fake `op` on PATH that prints a canned field
# value, so this runs anywhere: no vault, no network, no session. Every key
# below is an obvious placeholder.

set -eu

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
subject="$script_dir/op-key-sync.sh"

pass=0
fail=0
ok() { echo "  ok: $1"; pass=$((pass + 1)); }
ko() { echo "  FAIL: $1"; fail=$((fail + 1)); }

ORIG_PATH="$PATH"
unset OP_SERVICE_ACCOUNT_TOKEN DOTFILES_OP_TOKEN_FILE DOTFILES_OP_VAULT

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT

new_sandbox() {
  sandbox="$(mktemp -d "$root/case.XXXXXX")"
  mkdir -p "$sandbox/home" "$sandbox/bin"
  export HOME="$sandbox/home"
  export PATH="$sandbox/bin:$ORIG_PATH"
  export OP_STUB_VALUE="$sandbox/value"
  export OP_STUB_ARGV="$sandbox/argv"
  unset OP_STUB_FAIL
  out="$HOME/.config/dotfiles/test-api-key"
  printf '%s' 'placeholder-key-0001' >"$OP_STUB_VALUE"
  cat >"$sandbox/bin/op" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$OP_STUB_ARGV"
if [ -n "${OP_STUB_FAIL:-}" ]; then
  echo "[ERROR] stubbed op failure" >&2
  exit 1
fi
[ "$1 $2" = "item get" ] || exit 2
cat "$OP_STUB_VALUE"
echo
FAKE
  chmod +x "$sandbox/bin/op"
}

run() { # run <args...>; sets rc, stdout, stderr and log (both)
  set +e
  "$subject" "$@" >"$sandbox/stdout" 2>"$sandbox/stderr"
  rc=$?
  set -e
  stdout="$(cat "$sandbox/stdout")"
  stderr="$(cat "$sandbox/stderr")"
  log="$stdout$stderr"
}

expect_failed() { # expect_failed <label> <needle>
  if [ "$rc" -eq 0 ]; then ko "$1: exited 0 ($log)"
  elif ! grep -qF "FAILED:" <<<"$stderr"; then ko "$1: no FAILED: line on stderr ($log)"
  elif ! grep -qF -- "$2" <<<"$log"; then ko "$1: expected \"$2\", got: $log"
  else ok "$1"; fi
}

mode_of() { stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"; }

echo "1. a fresh host gets the key at 0600, byte for byte"
new_sandbox
run test-item "$out"
if [ "$rc" -eq 0 ] && grep -q '^CHANGED' <<<"$stdout"; then ok "prints CHANGED on stdout"; else ko "prints CHANGED on stdout ($log)"; fi
[ "$(mode_of "$out" 2>/dev/null)" = 600 ] && ok "mode 0600" || ko "mode 0600"
[ "$(mode_of "$(dirname "$out")" 2>/dev/null)" = 700 ] && ok "directory 0700" || ko "directory 0700"
if [ "$(cat "$out")" = placeholder-key-0001 ] && [ "$(wc -c <"$out" | tr -d ' ')" = 20 ]; then
  ok "value written with no trailing newline"
else
  ko "value written with no trailing newline"
fi
if grep -q -- '--vault Dotfiles Service Account' "$OP_STUB_ARGV" && grep -q -- '--fields credential' "$OP_STUB_ARGV" \
  && grep -q -- '--reveal' "$OP_STUB_ARGV"; then
  ok "reads the credential field from the service-account vault"
else
  ko "reads the credential field from the service-account vault ($(cat "$OP_STUB_ARGV"))"
fi
if grep -q placeholder-key "$OP_STUB_ARGV"; then ko "op was called with the key"; else ok "op is called without the key"; fi
if [ -n "$(find "$(dirname "$out")" -name '.*' -type f)" ]; then ko "a temp file was left behind"; else ok "no temp file left behind"; fi

echo "2. a second run is a no-op"
run test-item "$out"
if [ "$rc" -eq 0 ] && grep -q '^OK' <<<"$stdout"; then ok "prints OK on stdout"; else ko "prints OK on stdout ($log)"; fi

echo "3. a changed key in 1Password rewrites the file"
printf '%s' 'placeholder-key-0002' >"$OP_STUB_VALUE"
run test-item "$out"
if [ "$rc" -eq 0 ] && grep -q '^CHANGED' <<<"$log" && [ "$(cat "$out")" = placeholder-key-0002 ]; then
  ok "rotated key lands"
else
  ko "rotated key lands ($log)"
fi

echo "4. a key file at a loose mode is refused, not tightened"
new_sandbox
mkdir -p "$(dirname "$out")"
printf '%s' 'placeholder-key-0001' >"$out"
chmod 644 "$out"
run test-item "$out"
expect_failed "loose mode refused" "mode 644"
[ "$(mode_of "$out")" = 644 ] && ok "file left as found for inspection" || ko "file left as found for inspection"
grep -q 'rotate' <<<"$log" && ok "says to rotate the key" || ko "says to rotate the key ($log)"
chmod 640 "$out"
run test-item "$out"
expect_failed "group-readable mode refused" "mode 640"

echo "5. a read-only key file at 0400 is accepted"
new_sandbox
mkdir -p "$(dirname "$out")"
printf '%s' 'placeholder-key-0001' >"$out"
chmod 400 "$out"
run test-item "$out"
if [ "$rc" -eq 0 ] && grep -q '^OK' <<<"$log"; then ok "0400 matching key is OK"; else ko "0400 matching key is OK ($log)"; fi

echo "6. a blank value in 1Password is refused and writes nothing"
new_sandbox
: >"$OP_STUB_VALUE"
run test-item "$out"
expect_failed "empty value refused" "blank"
[ -e "$out" ] && ko "a file was written" || ok "no file written"
printf ' \t ' >"$OP_STUB_VALUE"
run test-item "$out"
expect_failed "whitespace-only value refused" "blank"

echo "7. a value holding a line break is refused"
new_sandbox
printf 'placeholder\nsecond-line' >"$OP_STUB_VALUE"
run test-item "$out"
expect_failed "multi-line value refused" "line break"
[ -e "$out" ] && ko "a file was written" || ok "no file written"

echo "8. the output path must be a plain file"
new_sandbox
mkdir -p "$(dirname "$out")"
ln -s "$sandbox/elsewhere" "$out"
run test-item "$out"
expect_failed "symlink refused" "symlink"
[ -e "$sandbox/elsewhere" ] && ko "wrote through the link" || ok "nothing written through the link"
new_sandbox
mkdir -p "$out"
run test-item "$out"
expect_failed "directory refused" "not a regular file"

echo "9. an op failure is reported, never a silent skip"
new_sandbox
export OP_STUB_FAIL=1
run test-item "$out"
expect_failed "op failure" "test-item"

echo "10. arguments are checked before anything runs"
new_sandbox
run test-item
expect_failed "missing output" "usage"
run --vault "$out"
expect_failed "flag-like item name" "outside"
run test-item relative/path
expect_failed "relative output" "absolute"
[ -e "$OP_STUB_ARGV" ] && ko "op ran on a refused argument" || ok "op never ran"

echo "11. the key's directory must be the user's and closed to writers"
new_sandbox
mkdir -p "$(dirname "$out")"
chmod 777 "$(dirname "$out")"
run test-item "$out"
expect_failed "other-writable directory refused" "writable by other"
[ -e "$out" ] && ko "a key was written there" || ok "no key written there"
chmod 1777 "$(dirname "$out")"
run test-item "$out"
expect_failed "sticky other-writable directory refused" "writable by other"
chmod 775 "$(dirname "$out")"
run test-item "$out"
if [ "$(stat -c '%G' "$(dirname "$out")" 2>/dev/null || stat -f '%Sg' "$(dirname "$out")")" = "$(id -un)" ]; then
  if [ "$rc" -eq 0 ]; then ok "a directory writable only by a group named after you is accepted"; else ko "user-private group directory ($log)"; fi
else
  expect_failed "a group-writable directory in a shared group refused" "not a group of your own"
fi
chmod 2777 "$(dirname "$out")" 2>/dev/null
if [ "$(mode_of "$(dirname "$out")")" = 2777 ]; then
  run test-item "$out"
  expect_failed "setgid other-writable directory refused" "writable by other"
else
  echo "  SKIP: this stat does not print setgid"
fi
chmod 777 "$(dirname "$out")"
run test-item "$out"
expect_failed "an existing matching key in an other-writable directory is not OK" "writable by other"
chmod 755 "$(dirname "$out")"
run test-item "$out"
dir_mode="$(mode_of "$(dirname "$out")")"
if [ "$rc" -eq 0 ] && [ "${dir_mode#"${dir_mode%???}"}" = 755 ]; then ok "an existing directory is left at its own mode"; else ko "an existing directory is left at its own mode ($log)"; fi
if [ "$(id -G | wc -w)" -gt 1 ]; then
  other_group="$(id -G | tr ' ' '\n' | grep -vx "$(id -g)" | head -n 1)"
  if chgrp "$other_group" "$(dirname "$out")" 2>/dev/null && chmod 775 "$(dirname "$out")"; then
    run test-item "$out"
    expect_failed "a directory writable by another group refused" "not a group of your own"
  else
    echo "  SKIP: could not move the directory to another group"
  fi
else
  echo "  SKIP: this user belongs to one group only"
fi
new_sandbox
mkdir -p "$sandbox/real"
chmod 777 "$sandbox/real"
mkdir -p "$HOME/.config"
ln -s "$sandbox/real" "$HOME/.config/dotfiles"
run test-item "$out"
expect_failed "a symlinked directory is judged by its target" "writable by other"

echo "12. no shell config exports the key"
if grep -rq CUBIC "$script_dir/../roles/fish"; then ko "roles/fish mentions CUBIC"; else ok "roles/fish never mentions CUBIC"; fi

echo
echo "op-key-sync-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
