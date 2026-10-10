# shellcheck shell=bash
# Sourced by the scripts that read 1Password with the machine-local
# service-account token. The caller defines fail(); resolve_op_token sets
# OP_TOKEN_FILE and op_token and unsets OP_SERVICE_ACCOUNT_TOKEN, so `op` must
# be called through op_run, which hands the token to it alone.

# An explicit list, not a range or grep: a range follows the locale and grep
# passes an embedded newline. `-` last so it stays literal.
token_chars='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+/=._-'
is_token() {
  case "$1" in
    '' | *[!$token_chars]*) return 1 ;;
  esac
}

# Only the stripped copy is tested; the token itself is passed on unmodified.
is_blank() {
  [ -z "$(printf '%s' "$1" | LC_ALL=C tr -d '[:space:]')" ]
}

# has_acl <path>: the file carries an access-control list, which mode bits do
# not show. GNU ls marks one with a `+` after the mode; macOS ls prints a `@`
# there instead when the file also has extended attributes, so its `-e` entry
# lines are checked too (GNU ls has no `-e`, and prints nothing for it).
has_acl() {
  local mode_field
  mode_field="$(LC_ALL=C ls -ld -- "$1" 2>/dev/null)"
  mode_field="${mode_field%% *}"
  case "$mode_field" in *+) return 0 ;; esac
  [ -n "$(LC_ALL=C ls -lde -- "$1" 2>/dev/null | sed -n 2p)" ]
}

# owner_of <path>: the owning uid.
owner_of() { stat -c '%u' "$1" 2>/dev/null || stat -f '%u' "$1" 2>/dev/null || echo ''; }

resolve_op_token() {
  OP_TOKEN_FILE="${DOTFILES_OP_TOKEN_FILE:-$HOME/.config/dotfiles/op-service-account-token}"
  # Unset both: an inherited op_token stays exported, and an exported token,
  # even an empty one, must reach op through op_run alone.
  unset op_token
  op_token="${OP_SERVICE_ACCOUNT_TOKEN:-}"
  unset OP_SERVICE_ACCOUNT_TOKEN
  local perms unreadable
  if [ -n "$op_token" ]; then
    if is_blank "$op_token"; then
      fail "OP_SERVICE_ACCOUNT_TOKEN is set but contains only whitespace; unset it or supply a real token"
    fi
    is_token "$op_token" \
      || fail "OP_SERVICE_ACCOUNT_TOKEN holds a non-token value; unset it or supply a real token"
  elif [ -e "$OP_TOKEN_FILE" ] || [ -L "$OP_TOKEN_FILE" ]; then
    # Every check below would otherwise follow a link to wherever it points.
    if [ -L "$OP_TOKEN_FILE" ]; then
      fail "$OP_TOKEN_FILE is a symlink; replace it with a regular file holding the service-account token"
    fi
    if [ ! -f "$OP_TOKEN_FILE" ]; then
      fail "$OP_TOKEN_FILE is not a regular file; remove it or replace it with the service-account token"
    fi
    # An empty file would switch off the desktop-app path that would have worked.
    if [ ! -s "$OP_TOKEN_FILE" ]; then
      fail "$OP_TOKEN_FILE exists but is empty; write the service-account token to it or remove it (an empty file disables the desktop-app fallback)"
    fi
    perms="$(stat -c '%a' "$OP_TOKEN_FILE" 2>/dev/null || stat -f '%Lp' "$OP_TOKEN_FILE" 2>/dev/null || echo '')"
    case "$perms" in
      600 | 400) ;;
      '') fail "could not stat token file $OP_TOKEN_FILE" ;;
      *) fail "$OP_TOKEN_FILE is mode $perms; must be 600 or 400 (chmod 600 it)" ;;
    esac
    # Mode bits alone let another owner, or an ACL, grant someone else access.
    [ "$(owner_of "$OP_TOKEN_FILE")" = "$(id -u)" ] \
      || fail "$OP_TOKEN_FILE is not owned by this user; recreate it as this user"
    if has_acl "$OP_TOKEN_FILE"; then
      fail "$OP_TOKEN_FILE carries an access-control list; remove it (chmod -N on macOS, setfacl -b on Linux)"
    fi
    # Through fail(): under `set -e` a root-owned file would abort on cat's
    # status with no FAILED: line.
    unreadable="$OP_TOKEN_FILE is not readable by this user (mode is $perms, but check the owner)"
    [ -r "$OP_TOKEN_FILE" ] || fail "$unreadable"
    # Before the read: $(...) drops NUL bytes, and bash 4.4+ warns as it does.
    if ! LC_ALL=C tr -d '\000' <"$OP_TOKEN_FILE" | cmp -s - "$OP_TOKEN_FILE"; then
      fail "$OP_TOKEN_FILE holds a non-token value; write the service-account token to it or remove it"
    fi
    op_token="$(cat "$OP_TOKEN_FILE" 2>/dev/null)" || fail "$unreadable"
    if is_blank "$op_token"; then
      fail "$OP_TOKEN_FILE contains only whitespace; write the service-account token to it or remove it"
    fi
    is_token "$op_token" \
      || fail "$OP_TOKEN_FILE holds a non-token value; write the service-account token to it or remove it"
  fi
}

op_run() {
  if [ -n "$op_token" ]; then
    OP_SERVICE_ACCOUNT_TOKEN="$op_token" op "$@"
  else
    op "$@"
  fi
}
