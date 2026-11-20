#!/bin/sh
# Runs tpm for tmux.conf, only on the default socket of a server that has a
# session, and with every tmux call tpm and its plugins make unable to start a
# server.
#
# Without this, a short-lived private server (`tmux -L <name> new-session -d`,
# killed a moment later) ran tpm in the background; tpm's children outlived it
# and their `tmux list-keys` (a command that starts a server) re-created a
# server on the dead socket, which loaded tmux.conf and ran tpm again. The
# chain kept itself alive for days.
#
# The session check polls instead of reading the count once: tmux loads its
# config before the session that started it exists, so a fresh start sees
# none for a moment.

real_tmux=$(command -v tmux) || exit 0
# A server started from inside tpm inherits the shim on PATH; the shim would exec itself.
case $real_tmux in */tpm-guard-bin/tmux) exit 0 ;; esac
socket=${TMUX%%,*}
[ -n "$socket" ] || exit 0
[ "${socket##*/}" = default ] || exit 0

tries=50
while :; do
	# -N throughout: a query must never be what starts a server.
	sessions=$("$real_tmux" -N -S "$socket" list-sessions -F x 2>/dev/null) || exit 0
	[ -n "$sessions" ] && break
	tries=$((tries - 1))
	[ "$tries" -gt 0 ] || exit 0
	sleep 0.1
done

guard_dir=$(cd "$(dirname "$0")" && pwd) || exit 0
TPM_GUARD_REAL_TMUX=$real_tmux
PATH="$guard_dir/tpm-guard-bin:$PATH"
export TPM_GUARD_REAL_TMUX PATH
exec "$HOME/.tmux/plugins/tpm/tpm"
