#!/bin/sh
# The only thing the monitoring key is allowed to run (specs/linux-migration
# Task 10, REQ-E1.6). Managed by roles/linux; installed to
# /usr/local/bin/dotfiles-health-report.
#
# REQ-E1.6 says the health signal must not deploy anything long-running on this
# host, which is what preserves the spec's no-services scope. So there is no
# daemon, no timer and no listener here: `work` polls over the existing SSH path
# and this script runs for a few milliseconds per poll and exits. The host is
# entirely passive.
#
# Reached through a forced command in ~/.ssh/authorized_keys.monitoring, so it
# takes NO arguments and reads no input -- whatever the client asks for,
# sshd runs exactly this. Anything the caller sends is ignored by construction.
#
# Output is one line of key=value pairs, chosen so the poller can parse it with
# plain shell rather than needing jq on the far end:
#
#   status=ok disk_pct=6 disk_avail=868G uptime_s=12345 load1=0.42
#
# Deliberately discloses nothing sensitive. A monitoring credential is a
# lower-trust credential than a login one -- it is stored unattended on the
# runner machine so it can fire without a human -- so this reports capacity and
# liveness only: no hostname, no addresses, no package or user inventory,
# nothing that would help someone who obtained the key learn about the host.
#
# POSIX sh with no dependencies beyond coreutils, so it cannot break from a
# missing package.

set -eu

# Root filesystem is the one that matters: it holds /home, the LUKS volume and
# anything a future service spec will fill up.
disk_pct=$(df -P / | awk 'NR==2 {gsub(/%/, "", $5); print $5}')
disk_avail=$(df -Ph / | awk 'NR==2 {print $4}')

# Integer seconds since boot. The poller can use this to notice an unexpected
# reboot -- uptime going BACKWARDS between polls means the host restarted, which
# is worth knowing even though the host was reachable both times.
uptime_s=$(awk '{printf "%d", $1}' /proc/uptime)

load1=$(awk '{print $1}' /proc/loadavg)

printf 'status=ok disk_pct=%s disk_avail=%s uptime_s=%s load1=%s\n' \
    "$disk_pct" "$disk_avail" "$uptime_s" "$load1"
