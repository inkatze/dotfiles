#!/usr/bin/env bash
# inbox-sweep.sh — remove stale inbox entries.
#
# Per D-23: entries with last-heartbeat older than 2 minutes are auto-removed
# by readers (dashboard, status segment) before display. Entries with no
# last-heartbeat field age out at 24 hours as a legacy fallback. As an extra
# backstop (orphaned heartbeats after a kill -9), entries whose recorded
# Claude PID is no longer alive on this host are also removed.
#
# Subcommands:
#   sweep                   Remove stale entries. Silent on success.
#   list                    Print paths of currently-live entries (post-sweep).
#                           Used by dashboard + status to avoid re-scanning.
#
# This script is read+delete only. It never modifies entry contents.

set -u

INBOX_DIR="${PAIR_FLOW_INBOX:-$HOME/.claude/inbox}"
HOST=$(hostname -s 2>/dev/null || hostname)
STALE_SECONDS="${PAIR_FLOW_STALE_SECONDS:-120}"     # D-23: 2 minutes.
LEGACY_SECONDS="${PAIR_FLOW_LEGACY_SECONDS:-86400}" # D-23: 24 hours.

mkdir -p "$INBOX_DIR" 2>/dev/null || true

# Epoch from ISO 8601. BSD date.
iso_to_epoch() {
    [ -z "$1" ] && return 1
    date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s 2>/dev/null
}

now_epoch=$(date -u +%s)

sweep_one() {
    local path="$1"
    [ ! -f "$path" ] && return 0
    local heartbeat first_seen entry_host entry_pid age legacy_age
    heartbeat=$(jq -r '."last-heartbeat" // empty' "$path" 2>/dev/null)
    first_seen=$(jq -r '."first-seen" // empty' "$path" 2>/dev/null)
    entry_host=$(jq -r '.host // empty' "$path" 2>/dev/null)
    entry_pid=$(jq -r '.pid // empty' "$path" 2>/dev/null)

    if [ -n "$heartbeat" ]; then
        local hb_epoch
        hb_epoch=$(iso_to_epoch "$heartbeat") || hb_epoch=0
        age=$((now_epoch - hb_epoch))
        if [ "$age" -gt "$STALE_SECONDS" ]; then
            rm -f "$path"
            return 0
        fi
    else
        # Legacy entries with no heartbeat: age out at 24h.
        local fs_epoch
        fs_epoch=$(iso_to_epoch "$first_seen") || fs_epoch=0
        legacy_age=$((now_epoch - fs_epoch))
        if [ "$legacy_age" -gt "$LEGACY_SECONDS" ]; then
            rm -f "$path"
            return 0
        fi
    fi

    # PID liveness check only for entries from this host (cross-host PIDs are
    # meaningless locally).
    if [ -n "$entry_pid" ] && [ "$entry_pid" != "null" ] && [ "$entry_host" = "$HOST" ]; then
        if ! kill -0 "$entry_pid" 2>/dev/null; then
            rm -f "$path"
            return 0
        fi
    fi
}

cmd="${1:-sweep}"

case "$cmd" in
    sweep)
        for f in "$INBOX_DIR"/*.json; do
            [ -e "$f" ] || continue
            sweep_one "$f"
        done
        ;;
    list)
        for f in "$INBOX_DIR"/*.json; do
            [ -e "$f" ] || continue
            sweep_one "$f"
            [ -f "$f" ] && printf '%s\n' "$f"
        done
        ;;
    *)
        printf 'inbox-sweep: unknown subcommand: %s\n' "$cmd" >&2
        exit 2
        ;;
esac
