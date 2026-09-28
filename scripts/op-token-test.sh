#!/usr/bin/env bash
# Tests for the service-account token resolution in scripts/op-token.sh,
# driven through both scripts that source it. `op` is a stub on PATH and every
# token here is a fake, so this needs no vault, network or session.

set -eu

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
subjects="claude-gemini-auth-sync.sh ssh-lan-config-sync.sh"

unset OP_SERVICE_ACCOUNT_TOKEN DOTFILES_OP_TOKEN_FILE DOTFILES_OP_VAULT \
  DOTFILES_OP_ITEM GEMINI_OP_ITEM_UUID GEMINI_OP_VAULT

ORIG_PATH="$PATH"
real_chmod="$(command -v chmod)"
root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT

pass=0
fail=0
ok() { echo "  ok: $1"; pass=$((pass + 1)); }
ko() { echo "  FAIL: $1"; fail=$((fail + 1)); }

good="ops_fAkEtOkEn-base64url_x"
nbsp="$(printf '\302\240')"

# The chmod shim records any call that inherited the token: both scripts run
# chmod after `op`, so it catches an exported copy leaking past op_run.
new_sandbox() {
  sandbox="$(mktemp -d "$root/case.XXXXXX")"
  mkdir -p "$sandbox/home" "$sandbox/bin"
  export HOME="$sandbox/home"
  export PATH="$sandbox/bin:$ORIG_PATH"
  token_file="$sandbox/token"
  cat >"$sandbox/bin/op" <<FAKE
#!/usr/bin/env bash
set -eu
printf 'token=%s\n' "\${OP_SERVICE_ACCOUNT_TOKEN-<unset>}" >>"$sandbox/op.log"
FAKE
  cat >>"$sandbox/bin/op" <<'FAKE'
case "${1:-}" in
  item) printf 'fake-gemini-key' ;;
  inject)
    in_file=""; out_file=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --in-file) in_file="$2"; shift 2 ;;
        --out-file) out_file="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    sed -E \
      -e 's|\{\{ op://[^/]+/[^/]+/server_alias \}\}|testbox|g' \
      -e 's|\{\{ op://[^/]+/[^/]+/server_host \}\}|testbox.example|g' \
      -e 's|\{\{ op://[^/]+/[^/]+/server_ip \}\}|192.0.2.9|g' \
      -e 's|\{\{ op://[^/]+/[^/]+/server_user \}\}|tester|g' \
      "$in_file" >"$out_file"
    ;;
esac
FAKE
  cat >"$sandbox/bin/chmod" <<SHIM
#!/usr/bin/env bash
[ -z "\${OP_SERVICE_ACCOUNT_TOKEN+x}" ] || echo leaked >>"$sandbox/leak.log"
exec "$real_chmod" "\$@"
SHIM
  "$real_chmod" +x "$sandbox/bin/op" "$sandbox/bin/chmod"
}

# write_token <printf-format>: the format carries the bytes, so NULs and
# newlines can be planted.
write_token() {
  # shellcheck disable=SC2059
  (umask 077; printf "$1" >"$token_file")
}

run() { # run <subject> [VAR=value ...]
  subject_path="$script_dir/$1"
  shift
  if out="$(env "$@" "$subject_path" 2>&1)"; then rc=0; else rc=$?; fi
}

no_echo() { # no_echo <label>
  case "$out" in
    *fAkEtOkEn*) ko "$1: output echoes the token" ;;
  esac
  if [ -e "$sandbox/leak.log" ]; then ko "$1: token leaked into a later child"; fi
  return 0
}

refused() { # refused <label> <expected message after "FAILED: ">
  if [ "$rc" -eq 0 ]; then
    ko "$1: expected refusal, got: $out"
  elif [ -e "$sandbox/op.log" ]; then
    ko "$1: op was called despite refusal"
  else
    case "$out" in
      *"FAILED: $2"*) ok "$1: refused" ;;
      *) ko "$1: unexpected message: $out" ;;
    esac
  fi
  no_echo "$1"
}

accepted() { # accepted <label> <token op must receive, or <unset>>
  if [ "$rc" -ne 0 ]; then
    ko "$1: expected success, got: $out"
  elif ! grep -qxF "token=$2" "$sandbox/op.log" 2>/dev/null; then
    ko "$1: op did not receive token=$2 ($(cat "$sandbox/op.log" 2>/dev/null))"
  else
    ok "$1: accepted"
  fi
  no_echo "$1"
}

file_refused() { # file_refused <subject> <label> <printf-format> <message suffix>
  new_sandbox
  write_token "$3"
  run "$1" DOTFILES_OP_TOKEN_FILE="$token_file"
  refused "$2" "$token_file $4"
}

file_accepted() { # file_accepted <subject> <label> <printf-format> <expected token>
  new_sandbox
  write_token "$3"
  run "$1" DOTFILES_OP_TOKEN_FILE="$token_file"
  accepted "$2" "$4"
}

env_refused() { # env_refused <subject> <label> <value> <message suffix>
  new_sandbox
  run "$1" OP_SERVICE_ACCOUNT_TOKEN="$3"
  refused "$2" "OP_SERVICE_ACCOUNT_TOKEN $4"
}

non_token="holds a non-token value; write the service-account token to it or remove it"
env_non_token="holds a non-token value; unset it or supply a real token"

for s in $subjects; do
  echo "== $s"

  echo "1. token file contents"
  file_refused "$s" "NBSP only" "$nbsp\n" "$non_token"
  file_refused "$s" "NBSP-padded" "$nbsp$good\n" "$non_token"
  file_refused "$s" "embedded space" 'ops_fAkEtOkEn tail\n' "$non_token"
  file_refused "$s" "embedded tab" 'ops_fAkEtOkEn\ttail\n' "$non_token"
  file_refused "$s" "embedded newline" 'ops_fAkEtOkEn\nsecond\n' "$non_token"
  file_refused "$s" "trailing CR" 'ops_fAkEtOkEn\r\n' "$non_token"
  file_refused "$s" "double-quoted" '"ops_fAkEtOkEn"\n' "$non_token"
  file_refused "$s" "single-quoted" "'ops_fAkEtOkEn'\n" "$non_token"
  file_refused "$s" "embedded NUL" 'ops_fAkEtOkEn\000tail\n' "$non_token"
  file_refused "$s" "NUL only" '\000' "$non_token"
  file_refused "$s" "whitespace only" '  \t \n' \
    "contains only whitespace; write the service-account token to it or remove it"
  file_refused "$s" "empty" '' \
    "exists but is empty; write the service-account token to it or remove it (an empty file disables the desktop-app fallback)"
  file_accepted "$s" "base64url, trailing newline" "$good\n" "$good"
  file_accepted "$s" "base64 with padding, no newline" 'ops_fAkEtOkEn+tok/en==' 'ops_fAkEtOkEn+tok/en=='
  file_accepted "$s" "JWT-shaped" 'eyJfAkEtOkEn.eyJwYXkiOjF9.c2ln\n' 'eyJfAkEtOkEn.eyJwYXkiOjF9.c2ln'

  echo "2. token file mode and type"
  for mode in 644 640 604 700 660; do
    new_sandbox
    write_token "$good\n"
    "$real_chmod" "$mode" "$token_file"
    run "$s" DOTFILES_OP_TOKEN_FILE="$token_file"
    refused "mode $mode" "$token_file is mode $mode; must be 600 or 400 (chmod 600 it)"
  done

  new_sandbox
  write_token "$good\n"
  "$real_chmod" 400 "$token_file"
  run "$s" DOTFILES_OP_TOKEN_FILE="$token_file"
  accepted "mode 400" "$good"

  new_sandbox
  mkdir "$token_file"
  run "$s" DOTFILES_OP_TOKEN_FILE="$token_file"
  refused "directory" "$token_file is not a regular file; remove it or replace it with the service-account token"

  new_sandbox
  mkfifo "$token_file"
  run "$s" DOTFILES_OP_TOKEN_FILE="$token_file"
  refused "fifo" "$token_file is not a regular file; remove it or replace it with the service-account token"

  # A link to a well-formed 0600 token: only the link itself is at fault. BSD
  # chmod -h can give the link a mode the mode check would otherwise accept.
  new_sandbox
  (umask 077; printf '%s\n' "$good" >"$sandbox/real-token")
  ln -s "$sandbox/real-token" "$token_file"
  "$real_chmod" -h 600 "$token_file" 2>/dev/null || true
  run "$s" DOTFILES_OP_TOKEN_FILE="$token_file"
  refused "symlink" "$token_file is a symlink; replace it with a regular file holding the service-account token"

  new_sandbox
  ln -s "$sandbox/missing" "$token_file"
  run "$s" DOTFILES_OP_TOKEN_FILE="$token_file"
  refused "dangling symlink" "$token_file is a symlink; replace it with a regular file holding the service-account token"

  echo "3. default path and absence"
  new_sandbox
  mkdir -p "$HOME/.config/dotfiles"
  (umask 077; printf '%s\n' "$good" >"$HOME/.config/dotfiles/op-service-account-token")
  run "$s"
  accepted "default token path" "$good"

  new_sandbox
  run "$s"
  accepted "no token anywhere uses the desktop app" "<unset>"

  echo "4. exported token"
  env_refused "$s" "NBSP only" "$nbsp" "$env_non_token"
  env_refused "$s" "embedded space" "ops_fAkEtOkEn tail" "$env_non_token"
  env_refused "$s" "embedded newline" "ops_fAkEtOkEn
second" "$env_non_token"
  env_refused "$s" "quoted" "\"ops_fAkEtOkEn\"" "$env_non_token"
  env_refused "$s" "whitespace only" "   " \
    "is set but contains only whitespace; unset it or supply a real token"

  new_sandbox
  run "$s" OP_SERVICE_ACCOUNT_TOKEN="$good"
  accepted "valid exported token" "$good"

  new_sandbox
  write_token 'not a token at all\n'
  "$real_chmod" 644 "$token_file"
  run "$s" OP_SERVICE_ACCOUNT_TOKEN="$good" DOTFILES_OP_TOKEN_FILE="$token_file"
  accepted "exported token wins over a bad file" "$good"

  new_sandbox
  write_token 'ops_fAkEtOkEn_from_file\n'
  run "$s" OP_SERVICE_ACCOUNT_TOKEN="$good" DOTFILES_OP_TOKEN_FILE="$token_file"
  accepted "exported token wins over a good file" "$good"

  echo "5. invocation"
  new_sandbox
  write_token "$good\n"
  mkdir "$sandbox/links"
  ln -s "$script_dir/$s" "$sandbox/links/real"
  ln -s real "$sandbox/links/hop"
  if out="$(cd / && DOTFILES_OP_TOKEN_FILE="$token_file" "$sandbox/links/hop" 2>&1)"; then rc=0; else rc=$?; fi
  accepted "via a relative symlink chain from /" "$good"
done

echo
echo "passed: $pass   failed: $fail"
[ "$fail" -eq 0 ]
