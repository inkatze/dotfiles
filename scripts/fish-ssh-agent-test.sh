#!/usr/bin/env bash
# Fixture suite for the SSH-login agent selection in config.fish.
#
# The rule, shared with the IdentityAgent blocks in roles/ssh/files/config: the
# local 1Password agent is for someone at this machine's screen. Over SSH on
# Linux its approval prompt appears where nobody is looking, so the agent the
# client forwarded must win; on macOS the local 1Password still wins, because
# the launchd agent it would otherwise capture holds no keys.
#
# Runs the real config.fish in an interactive fish with a scratch HOME and
# placeholder sockets, since the block only fires for interactive SSH logins.
set -uo pipefail

here="$(cd -- "$(dirname "$0")" && pwd -P)"
repo="$(cd -- "$here/.." && pwd -P)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT TERM HUP
fails=0

ok()   { printf 'ok[%s]: %s\n' "$1" "$2"; }
fail() { printf 'FAIL[%s]: %s\n' "$1" "$2"; fails=$((fails + 1)); }

command -v fish >/dev/null || { echo "fish-ssh-agent-test: fish not found" >&2; exit 1; }

# A bound unix socket with nothing listening is enough for `test -S`.
mksock() { python3 -c 'import socket,sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$1"; }

if [ "$(uname)" = Darwin ]; then
    onep_rel="Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
else
    onep_rel=".1password/agent.sock"
fi

# $1: case name. Echoes the scratch HOME, with ~/.ssh and the config in place.
fresh_home() {
    h="$work/$1"
    mkdir -p "$h/.ssh" "$h/.config/fish"
    ln -s "$repo/roles/fish/files/fish/config.fish" "$h/.config/fish/config.fish"
    printf '%s\n' "$h"
}

# $1: home, $2: SSH_AUTH_SOCK the login arrives with. Prints auth_sock's target.
login() {
    env -i HOME="$1" XDG_CONFIG_HOME="$1/.config" PATH="$PATH" TERM=dumb \
        SSH_CONNECTION="192.0.2.1 50000 192.0.2.2 22" SSH_AUTH_SOCK="$2" \
        fish -i -c 'true' >/dev/null 2>&1 </dev/null
    readlink "$1/.ssh/auth_sock"
}

h="$(fresh_home both)"
mkdir -p "$(dirname "$h/$onep_rel")"; mksock "$h/$onep_rel"
fwd="$work/both-forwarded.sock"; mksock "$fwd"
got="$(login "$h" "$fwd")"
if [ "$(uname)" = Darwin ]; then
    if [ "$got" = "$h/$onep_rel" ]; then
        ok darwin-prefers-1password "local 1Password wins over the forwarded agent"
    else
        fail darwin-prefers-1password "auth_sock -> '$got'"
    fi
else
    if [ "$got" = "$fwd" ]; then
        ok linux-prefers-forwarded "the forwarded agent wins over the local 1Password"
    else
        fail linux-prefers-forwarded "auth_sock -> '$got'"
    fi
fi

h="$(fresh_home forwarded-only)"
fwd="$work/only-forwarded.sock"; mksock "$fwd"
got="$(login "$h" "$fwd")"
if [ "$got" = "$fwd" ]; then
    ok forwarded-only "the forwarded agent is captured"
else
    fail forwarded-only "auth_sock -> '$got'"
fi

if [ "$fails" -eq 0 ]; then
    echo "fish-ssh-agent-test: all assertions hold"
else
    echo "fish-ssh-agent-test: $fails assertion(s) failed"
    exit 1
fi
