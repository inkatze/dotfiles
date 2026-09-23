#!/usr/bin/env bash
# Fixture suite for the SSH-login agent selection in config.fish.
#
# The rule, shared with the IdentityAgent blocks in roles/ssh/files/config: the
# local 1Password agent is for someone at this machine's screen. Over SSH on
# Linux its approval prompt appears where nobody is looking, so the agent the
# client forwarded must win; on macOS the local 1Password still wins, because
# the launchd agent it would otherwise capture holds none of the 1Password
# keys.
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

# Bound at a short path and linked into place: the macOS 1Password path under
# a runner's temp directory exceeds the 104-byte socket-path limit.
fake_onep() {
    mkdir -p "$(dirname "$1/$onep_rel")"
    mksock "$work/onep-$2.sock"
    ln -s "$work/onep-$2.sock" "$1/$onep_rel"
}

h="$(fresh_home both)"
fake_onep "$h" both
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

# A login without forwarding can still arrive with macOS's launchd agent in
# SSH_AUTH_SOCK. It holds none of the 1Password keys, so capturing it breaks
# auth and signing for every shell that follows the link.
h="$(fresh_home launchd)"
mkdir -p "$work/com.apple.launchd.t"
launchd="$work/com.apple.launchd.t/Listeners"; mksock "$launchd"
prior="$work/launchd-prior.sock"; mksock "$prior"
ln -s "$prior" "$h/.ssh/auth_sock"
got="$(login "$h" "$launchd")"
if [ "$(uname)" = Darwin ]; then
    if [ "$got" = "$prior" ]; then
        ok darwin-ignores-launchd "the launchd agent leaves the existing link alone"
    else
        fail darwin-ignores-launchd "auth_sock -> '$got'"
    fi
else
    if [ ! -e "$h/.ssh/auth_sock" ] && [ ! -L "$h/.ssh/auth_sock" ]; then
        ok linux-ignores-launchd "the launchd agent is treated as nothing forwarded"
    else
        fail linux-ignores-launchd "auth_sock -> '$got'"
    fi
fi

if [ "$(uname)" != Darwin ]; then
    # With nothing forwarded, a link left on the local 1Password would hang
    # every ssh until a forwarded login repoints it; no link fails fast.
    h="$(fresh_home no-forward)"
    fake_onep "$h" no-forward
    ln -s "$h/$onep_rel" "$h/.ssh/auth_sock"
    login "$h" "" >/dev/null
    if [ ! -e "$h/.ssh/auth_sock" ] && [ ! -L "$h/.ssh/auth_sock" ]; then
        ok linux-no-forward-unlinks "a login without forwarding drops the link"
    else
        fail linux-no-forward-unlinks "auth_sock -> '$(readlink "$h/.ssh/auth_sock")'"
    fi

    # A shell nested in an SSH login (a new tmux pane) already carries the
    # stable path; treating that as "nothing forwarded" would drop the agent
    # out from under the session.
    h="$(fresh_home nested)"
    fwd="$work/nested-forwarded.sock"; mksock "$fwd"
    ln -s "$fwd" "$h/.ssh/auth_sock"
    got="$(login "$h" "$h/.ssh/auth_sock")"
    if [ "$got" = "$fwd" ]; then
        ok nested-shell-keeps-link "a nested shell leaves the link alone"
    else
        fail nested-shell-keeps-link "auth_sock -> '$got'"
    fi
fi

if [ "$fails" -eq 0 ]; then
    echo "fish-ssh-agent-test: all assertions hold"
else
    echo "fish-ssh-agent-test: $fails assertion(s) failed"
    exit 1
fi
