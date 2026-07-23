#!/usr/bin/env bash
# teardown-media-server.sh — one-shot, idempotent teardown of the media-server
# stack (Stremio/zurg/autoheal Docker services, the stremio watchdog, and the
# Plex + Stremio applications) from the personal host.
#
# Part of specs/media-server-cleanup. Authored by Task 2; executed and verified
# on the host by Task 3; deleted at close-out by Task 5 (git history is the
# reference for the future media re-add, D-5).
#
# Ordering (D-1): supervisors before services. The watchdog (a launchd agent
# that restarts the stack and colima every 5 minutes) and autoheal (a
# container-level restart layer) are disabled first so no later step races a
# recovery loop. The order is:
#   1. watchdog  — bootout by label, drain any in-flight run, remove plist+logs
#   2. containers — autoheal first, then stremio-server and zurg; delete volumes
#   3. config     — remove ~/.config/stremio-server (holds the rendered token)
#   4. apps       — bootout Plex helper, stop Plex server, quit Stremio, verify
#                   exited, then `brew uninstall --zap` the Plex + Stremio casks
#   5. sweep      — remove the known leftover ~/Library paths the zap misses
#   6. keychain   — delete the OP_SERVICE_ACCOUNT_TOKEN entry (last, D-1)
#
# Idempotent (REQ-D1.2): every step is a guarded no-op when its target is
# already absent, so a second run exits zero having changed nothing.
#
# No repo paths (D-2): after Task 1 lands, the symlinks in
# ~/.config/stremio-server dangle, so every target name is hardcoded here and
# the script never runs `docker compose -f <symlink>` or otherwise paths into
# the repo. Direct `docker rm` / `docker volume rm` / `launchctl bootout` by
# label are used instead.
#
# No secrets (REQ-C1.2): the keychain entry and the rendered zurg config are
# deleted by name/path only; their values are never read or printed.
#
# Scope (REQ-B1.7): only the three named containers and two named volumes are
# removed. colima, the docker runtime, and every other container (e.g. the
# Firebird dev container) are untouched. The ~/Library sweep is a curated list
# of paths owned by the four in-scope casks only; Plex-adjacent data that is
# NOT part of those casks (e.g. "Plex HTPC", "PlexTraktSync") is deliberately
# left for the Task 3 manual residual sweep (D-4) under human review.
#
# Docker daemon reachability is checked up front and aborts the run before any
# change if the daemon is unreachable: container state cannot be determined, so
# the docker steps must abort rather than silently skip (D-1 step 2). Start
# colima and re-run.

set -euo pipefail

UID_NUM="$(id -u)"
GUI_DOMAIN="gui/${UID_NUM}"

log() { printf '[teardown] %s\n' "$*"; }
skip() { printf '[teardown] skip: %s\n' "$*"; }

# Fail-fast: refuse to run a partial teardown when Docker state is unknowable.
require_docker() {
  if ! docker info >/dev/null 2>&1; then
    log "ERROR: docker daemon is unreachable — container state cannot be determined."
    log "ERROR: aborting before any change (docker steps abort, never skip)."
    log "ERROR: start colima (\`colima start\`) and re-run."
    exit 2
  fi
}

# Step 1 — watchdog: bootout by label, drain any in-flight invocation, then
# remove the plist and the /tmp logs.
teardown_watchdog() {
  local label="com.inkatze.stremio-watchdog"
  local plist="${HOME}/Library/LaunchAgents/${label}.plist"
  local invocation="stremio-watchdog.sh"

  if launchctl print "${GUI_DOMAIN}/${label}" >/dev/null 2>&1; then
    log "booting out launchd agent ${label}"
    launchctl bootout "${GUI_DOMAIN}/${label}" 2>/dev/null || true
  else
    skip "launchd agent not loaded: ${label}"
  fi

  # Drain: a watchdog invocation may have been mid-run when we booted the agent
  # out. Wait (bounded) for it to exit before removing its files.
  local waited=0
  while pgrep -f "${invocation}" >/dev/null 2>&1; do
    if [ "${waited}" -ge 60 ]; then
      log "warning: ${invocation} still running after ${waited}s; continuing"
      break
    fi
    log "waiting for in-flight ${invocation} to exit (${waited}s elapsed)"
    sleep 3
    waited=$((waited + 3))
  done

  if [ -e "${plist}" ]; then
    log "removing ${plist}"
    rm -f "${plist}"
  else
    skip "watchdog plist already absent"
  fi

  local logf
  for logf in /tmp/stremio-watchdog.stdout.log /tmp/stremio-watchdog.stderr.log; do
    if [ -e "${logf}" ]; then
      log "removing ${logf}"
      rm -f "${logf}"
    else
      skip "watchdog log already absent: ${logf}"
    fi
  done
}

# Step 2 — containers and volumes. autoheal first (it is itself a recovery
# layer), then the services; then the two compose-project-prefixed volumes.
teardown_containers() {
  local c
  for c in autoheal stremio-server zurg; do
    if docker ps -a --format '{{.Names}}' | grep -qx "${c}"; then
      log "stopping and removing container ${c}"
      docker stop "${c}" >/dev/null 2>&1 || true
      docker rm "${c}" >/dev/null
    else
      skip "container already absent: ${c}"
    fi
  done

  local v
  for v in stremio-server_stremio-data stremio-server_zurg-data; do
    if docker volume ls --format '{{.Name}}' | grep -qx "${v}"; then
      log "removing volume ${v}"
      docker volume rm "${v}" >/dev/null
    else
      skip "volume already absent: ${v}"
    fi
  done
}

# Step 3 — config directory (includes the rendered zurg config carrying the
# Real-Debrid token, and the now-dangling repo symlinks).
teardown_config() {
  local dir="${HOME}/.config/stremio-server"
  if [ -e "${dir}" ]; then
    log "removing ${dir} (rendered zurg config with the Real-Debrid token)"
    rm -rf "${dir}"
  else
    skip "config directory already absent: ${dir}"
  fi
}

# Quit a running .app gracefully, verify it exited, escalate to a signal only
# if it will not, and refuse to continue while it is still alive (so the cask
# is never zapped under a live process).
quit_app_verify() {
  local app="$1"
  local match="/${app}.app/"

  if ! pgrep -f "${match}" >/dev/null 2>&1; then
    skip "application not running: ${app}"
    return 0
  fi

  log "quitting ${app}"
  osascript -e "quit app \"${app}\"" >/dev/null 2>&1 || true

  local waited=0
  while pgrep -f "${match}" >/dev/null 2>&1; do
    if [ "${waited}" -ge 20 ]; then
      log "warning: ${app} did not quit after ${waited}s; sending TERM"
      pkill -f "${match}" 2>/dev/null || true
      sleep 2
      break
    fi
    sleep 2
    waited=$((waited + 2))
  done

  if pgrep -f "${match}" >/dev/null 2>&1; then
    log "ERROR: ${app} is still running; refusing to zap its cask while live"
    return 1
  fi
  log "${app} has exited"
}

# Step 4 — stop Plex (helper agent, then server), quit Stremio, verify both
# exited, then zap the Plex and Stremio casks.
teardown_apps() {
  local helper="tv.plex.player-helper"
  if launchctl print "${GUI_DOMAIN}/${helper}" >/dev/null 2>&1; then
    log "booting out launchd agent ${helper}"
    launchctl bootout "${GUI_DOMAIN}/${helper}" 2>/dev/null || true
  else
    skip "launchd agent not loaded: ${helper}"
  fi

  quit_app_verify "Plex Media Server"
  quit_app_verify "Stremio"

  local cask
  for cask in plex plex-media-player plex-media-server stremio; do
    if brew list --cask "${cask}" >/dev/null 2>&1; then
      log "brew uninstall --zap ${cask}"
      brew uninstall --zap "${cask}"
    else
      skip "cask already absent: ${cask}"
    fi
  done
}

# Step 5 — sweep the known leftover ~/Library paths the cask zap stanzas miss.
# Curated to the four in-scope casks only. Anything not listed here (Plex HTPC,
# PlexTraktSync, and any other residue) is left for the Task 3 manual residual
# sweep (D-4) under human review.
sweep_library() {
  local paths=(
    # plex-media-server cask (includes the ~589 MB library)
    "${HOME}/Library/Application Support/Plex Media Server"
    "${HOME}/Library/Logs/Plex Media Server"
    "${HOME}/Library/Caches/PlexMediaServer"
    "${HOME}/Library/Preferences/com.plexapp.plexmediaserver.plist"
    # plex-media-player cask
    "${HOME}/Library/Application Support/Plex Media Player"
    "${HOME}/Library/Logs/Plex Media Player"
    "${HOME}/Library/Caches/Plex Media Player"
    "${HOME}/Library/Preferences/tv.plex.Plex Media Player.plist"
    "${HOME}/Library/Saved Application State/tv.plex.player.savedState"
    # plex cask (Plex desktop app)
    "${HOME}/Library/Application Support/Plex"
    "${HOME}/Library/Logs/Plex"
    "${HOME}/Library/HTTPStorages/tv.plex.desktop"
    # stremio cask (current and prior-version residue)
    "${HOME}/Library/Application Support/stremio-server"
    "${HOME}/Library/Caches/com.westbridge.stremio5-mac"
    "${HOME}/Library/WebKit/com.westbridge.stremio5-mac"
    "${HOME}/Library/Preferences/com.westbridge.stremio5-mac.plist"
    "${HOME}/Library/Preferences/com.smartcodeltd.stremio.plist"
    "${HOME}/Library/Preferences/com.stremio.Stremio.plist"
  )
  local p
  for p in "${paths[@]}"; do
    if [ -e "${p}" ]; then
      log "removing leftover: ${p}"
      rm -rf "${p}"
    else
      skip "leftover already absent: ${p}"
    fi
  done
}

# Step 6 — keychain entry (last; independent and non-destructive to services).
teardown_keychain() {
  local acct="op-service-account"
  local svc="OP_SERVICE_ACCOUNT_TOKEN"
  if security find-generic-password -a "${acct}" -s "${svc}" >/dev/null 2>&1; then
    log "deleting keychain entry ${svc}"
    security delete-generic-password -a "${acct}" -s "${svc}" >/dev/null
  else
    skip "keychain entry already absent: ${svc}"
  fi
}

main() {
  log "media-server teardown starting"
  log "order: watchdog -> containers -> config -> apps -> library sweep -> keychain"
  require_docker
  teardown_watchdog
  teardown_containers
  teardown_config
  teardown_apps
  sweep_library
  teardown_keychain
  log "media-server teardown complete"
}

main "$@"
