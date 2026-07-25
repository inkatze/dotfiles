#!/usr/bin/env bash
# Tests for scripts/ssh-lan-config-sync.sh.
#
# The script's whole job is to fail closed: a half-rendered ~/.ssh/config.local
# breaks every ssh call on the host, so every guard below matters more than the
# happy path. 1Password is stubbed with a fake `op` on PATH, so this runs
# anywhere — no vault, no network, no authenticated session.

set -eu

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
subject="$script_dir/ssh-lan-config-sync.sh"

pass=0
fail=0

ok() { echo "  ok: $1"; pass=$((pass + 1)); }
ko() { echo "  FAIL: $1"; fail=$((fail + 1)); }

# Assert a regex matches in a file. A missing file is a failure, not a silent
# pass — grep's non-zero exit on ENOENT would otherwise read as "absent, good".
has_line() { # has_line <file> <regex> <label>
  if [ ! -f "$1" ]; then ko "$3 (file missing: $1)"; return; fi
  if grep -qE "$2" "$1"; then ok "$3"; else ko "$3"; fi
}
lacks_line() { # lacks_line <file> <regex> <label>
  if [ ! -f "$1" ]; then ko "$3 (file missing: $1)"; return; fi
  if grep -qE "$2" "$1"; then ko "$3"; else ok "$3"; fi
}

# Each case runs with a throwaway HOME and a throwaway PATH shim directory.
new_sandbox() {
  sandbox="$(mktemp -d)"
  mkdir -p "$sandbox/home" "$sandbox/bin"
  export HOME="$sandbox/home"
  export PATH="$sandbox/bin:$ORIG_PATH"
}

# A fake `op inject` that resolves any op:// reference to a canned value keyed
# by field name, so the test asserts on the script's behavior, not 1Password's.
install_fake_op() {
  cat >"$sandbox/bin/op" <<'FAKE'
#!/usr/bin/env bash
set -eu
in_file=""; out_file=""
while [ $# -gt 0 ]; do
  case "$1" in
    --in-file) in_file="$2"; shift 2 ;;
    --out-file) out_file="$2"; shift 2 ;;
    --file-mode) shift 2 ;;
    *) shift ;;
  esac
done
[ -n "$in_file" ] || exit 1
sed -E \
  -e 's|\{\{ op://[^/]+/[^/]+/server_alias \}\}|testbox|g' \
  -e 's|\{\{ op://[^/]+/[^/]+/server_host \}\}|testbox.local|g' \
  -e 's|\{\{ op://[^/]+/[^/]+/server_ip \}\}|10.9.9.9|g' \
  -e 's|\{\{ op://[^/]+/[^/]+/server_user \}\}|tester|g' \
  "$in_file" >"$out_file"
chmod 600 "$out_file"
FAKE
  chmod +x "$sandbox/bin/op"
}

ORIG_PATH="$PATH"

echo "1. op not installed -> FAILED, nothing written"
new_sandbox
if out="$("$subject" 2>&1)"; then
  ko "expected non-zero exit"
else
  case "$out" in
    *"FAILED:"*"op"*) ok "failed closed: $out" ;;
    *) ko "unexpected message: $out" ;;
  esac
fi
[ -e "$HOME/.ssh/config.local" ] && ko "wrote a file despite failing" || ok "no file written"

echo "2. happy path -> CHANGED, correct content, mode 0600"
new_sandbox; install_fake_op
if out="$("$subject" 2>&1)"; then
  case "$out" in
    CHANGED:*) ok "reported CHANGED" ;;
    *) ko "expected CHANGED, got: $out" ;;
  esac
else
  ko "expected success, got: $out"
fi
target="$HOME/.ssh/config.local"
has_line "$target" '^Host testbox 10\.9\.9\.9$' "alias+ip line rendered"
has_line "$target" '^    User tester$' "user rendered"
has_line "$target" '^    Hostname testbox\.local$' "hostname rendered"
lacks_line "$target" '\{\{' "no unsubstituted expressions"
if [ -f "$target" ] && grep -v '^[[:space:]]*#' "$target" | grep -q 'op://'; then
  ko "unresolved reference survived on a config line"
else
  ok "no unresolved references on config lines"
fi
[ -f "$target" ] && [ "$(stat -c '%a' "$target")" = "600" ] && ok "mode 0600" || ko "mode is $(stat -c '%a' "$target" 2>/dev/null)"
[ "$(stat -c '%a' "$HOME/.ssh")" = "700" ] && ok ".ssh mode 0700" || ko ".ssh mode wrong"

echo "3. re-run with no change -> OK, idempotent"
before="$(stat -c '%Y %s' "$target")"
if out="$("$subject" 2>&1)"; then
  case "$out" in
    OK:*) ok "reported OK" ;;
    *) ko "expected OK, got: $out" ;;
  esac
else
  ko "expected success, got: $out"
fi
[ "$(stat -c '%Y %s' "$target")" = "$before" ] && ok "file untouched" || ko "file rewritten on no-op run"

echo "4. unresolved reference -> FAILED, existing file preserved"
new_sandbox; install_fake_op
# Fake op that resolves nothing, simulating wrong field names on the item.
cat >"$sandbox/bin/op" <<'FAKE'
#!/usr/bin/env bash
set -eu
in_file=""; out_file=""
while [ $# -gt 0 ]; do
  case "$1" in
    --in-file) in_file="$2"; shift 2 ;;
    --out-file) out_file="$2"; shift 2 ;;
    --file-mode) shift 2 ;;
    *) shift ;;
  esac
done
sed 's|{{ \(op://[^}]*\) }}|\1|g' "$in_file" >"$out_file"
FAKE
chmod +x "$sandbox/bin/op"
mkdir -p "$HOME/.ssh"; printf 'Host keepme\n' >"$HOME/.ssh/config.local"; chmod 600 "$HOME/.ssh/config.local"
if out="$("$subject" 2>&1)"; then
  ko "expected non-zero exit on unresolved reference"
else
  case "$out" in
    *"unresolved secret reference"*) ok "detected unresolved reference" ;;
    *) ko "unexpected message: $out" ;;
  esac
fi
grep -q 'keepme' "$HOME/.ssh/config.local" && ok "pre-existing file preserved" || ko "clobbered existing config"

echo "5. target is a symlink -> refuse"
new_sandbox; install_fake_op
mkdir -p "$HOME/.ssh"; : >"$sandbox/elsewhere"
ln -s "$sandbox/elsewhere" "$HOME/.ssh/config.local"
if out="$("$subject" 2>&1)"; then
  ko "expected refusal on symlink target"
else
  case "$out" in
    *"symlink"*) ok "refused symlink target" ;;
    *) ko "unexpected message: $out" ;;
  esac
fi
[ -s "$sandbox/elsewhere" ] && ko "wrote through the symlink" || ok "symlink target untouched"

echo "6. render that does not parse -> refuse to install"
new_sandbox
cat >"$sandbox/bin/op" <<'FAKE'
#!/usr/bin/env bash
set -eu
out_file=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out-file) out_file="$2"; shift 2 ;;
    --in-file|--file-mode) shift 2 ;;
    *) shift ;;
  esac
done
printf 'Host bad\n    ThisIsNotAnSshOption yes\n' >"$out_file"
FAKE
chmod +x "$sandbox/bin/op"
if out="$("$subject" 2>&1)"; then
  ko "expected refusal on unparseable render"
else
  case "$out" in
    *"does not parse"*) ok "rejected unparseable config" ;;
    *) ko "unexpected message: $out" ;;
  esac
fi
[ -e "$HOME/.ssh/config.local" ] && ko "installed an unparseable config" || ok "nothing installed"

echo
echo "passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
