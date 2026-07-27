#!/bin/bash
# Polls the Linux server's health and pushes an alert when something is wrong
# (specs/linux-migration Task 10, REQ-E1.6). Managed by roles/osx; runs on the
# `work` Mac under a LaunchAgent.
#
# The direction matters. REQ-E1.6 forbids anything long-running on the server, so
# the server is passive: it exposes a forced-command script and this side does
# all the work. Nothing new listens anywhere, and no WAN exposure is added --
# this rides the SSH path that already exists.
#
# KNOWN BLIND SPOT, stated rather than discovered later: this runs on a laptop.
# If `work` is asleep, shut, or off-LAN when the server dies, the check simply
# does not run -- so "no alert" and "all healthy" are indistinguishable exactly
# when it matters most. REQ-E1.6 permits an external uptime monitor instead for
# this reason. The laptop was chosen deliberately; the limitation is real.

set -uo pipefail

CONF_DIR="$HOME/.config/dotfiles"
CREDS="$CONF_DIR/pushover-credentials"
TARGET_FILE="$CONF_DIR/health-target"
KEY="$HOME/.ssh/id_monitoring"
STATE="$HOME/.cache/dotfiles-health-state"
LOG="$HOME/.cache/dotfiles-health.log"

DISK_THRESHOLD=${DISK_THRESHOLD:-85}
SSH_TIMEOUT=15

mkdir -p "$(dirname "$STATE")"

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

# Pushover needs both halves and they come from different places: the user key
# identifies the recipient, the api token identifies the sending application.
# Read from a machine-local 0600 file rather than `op read` at poll time --
# 1Password's desktop integration authorizes per calling process, so a vault read
# every 15 minutes would prompt forever under launchd. Ansible renders this file
# once at playbook time; same pattern as op-service-account-token.
push() {
    local title="$1" message="$2" priority="${3:-0}"
    if [[ ! -r $CREDS ]]; then
        log "CANNOT ALERT: $CREDS missing or unreadable — $title: $message"
        return 1
    fi
    # shellcheck disable=SC1090
    . "$CREDS"
    curl -sS --max-time 20 \
        --form-string "token=${PUSHOVER_API_TOKEN:-}" \
        --form-string "user=${PUSHOVER_USER_KEY:-}" \
        --form-string "title=$title" \
        --form-string "message=$message" \
        --form-string "priority=$priority" \
        https://api.pushover.net/1/messages.json > /dev/null
}

# Alert only on TRANSITIONS, so a server that is down overnight produces one
# notification rather than 96. The recovery edge is notified too: an alert you
# never see cleared is an alert you learn to ignore.
transition() {
    local new="$1" title="$2" message="$3" priority="${4:-0}"
    local old=""
    [[ -r $STATE ]] && old=$(cat "$STATE")
    if [[ $old != "$new" ]]; then
        printf '%s' "$new" > "$STATE"
        log "state: ${old:-none} -> $new — $message"
        push "$title" "$message" "$priority"
    fi
}

[[ -r $TARGET_FILE ]] || { log "no $TARGET_FILE; nothing to poll"; exit 0; }
TARGET=$(tr -d '[:space:]' < "$TARGET_FILE")
[[ -n $TARGET ]] || { log "$TARGET_FILE is empty"; exit 0; }

# BatchMode so a missing or rejected key fails immediately instead of hanging on
# a prompt under launchd. IdentitiesOnly so the agent's other keys are not
# offered -- this key and no other.
report=$(ssh -n \
    -o BatchMode=yes \
    -o IdentitiesOnly=yes \
    -o ConnectTimeout="$SSH_TIMEOUT" \
    -i "$KEY" \
    "$TARGET" 2>/dev/null)
ssh_rc=$?

if [[ $ssh_rc -ne 0 || -z $report ]]; then
    transition unreachable "Server unreachable" \
        "No response over SSH (rc=$ssh_rc). Host may be down, rebooting, or the Mac is off-LAN." 1
    exit 0
fi

# The forced command returns key=value pairs; pull them without eval so a
# compromised or malfunctioning server cannot execute anything here.
disk_pct=$(printf '%s' "$report" | tr ' ' '\n' | awk -F= '$1=="disk_pct"{print $2}')
disk_avail=$(printf '%s' "$report" | tr ' ' '\n' | awk -F= '$1=="disk_avail"{print $2}')

if [[ ! $disk_pct =~ ^[0-9]+$ ]]; then
    transition malformed "Server health check malformed" \
        "Reachable but the report did not parse: $report" 0
    exit 0
fi

if (( disk_pct >= DISK_THRESHOLD )); then
    transition disk "Server disk ${disk_pct}% full" \
        "Root filesystem at ${disk_pct}% (threshold ${DISK_THRESHOLD}%), ${disk_avail} free." 1
    exit 0
fi

transition ok "Server healthy again" \
    "Reachable, disk ${disk_pct}% (${disk_avail} free)." 0
log "ok disk=${disk_pct}% avail=${disk_avail}"
