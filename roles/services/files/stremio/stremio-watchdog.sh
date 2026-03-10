#!/bin/bash
# stremio-watchdog.sh — Host-level watchdog for Stremio Docker service
# Runs via launchd every 5 minutes to ensure Stremio stays responsive.

set -euo pipefail

LOG_TAG="stremio-watchdog"
COMPOSE_DIR="$HOME/.config/stremio-server"
STREMIO_URL="http://localhost:11470"
MAX_RETRIES=3
RETRY_DELAY=5

log() {
  logger -t "$LOG_TAG" "$1"
}

check_stremio() {
  for i in $(seq 1 "$MAX_RETRIES"); do
    if curl -sf --max-time 10 "$STREMIO_URL" > /dev/null 2>&1; then
      return 0
    fi
    if [ "$i" -lt "$MAX_RETRIES" ]; then
      sleep "$RETRY_DELAY"
    fi
  done
  return 1
}

# Ensure Colima is running
if ! colima status > /dev/null 2>&1; then
  log "Colima is not running. Starting colima..."
  colima start
  sleep 10
  if ! colima status > /dev/null 2>&1; then
    log "ERROR: Failed to start Colima. Exiting."
    exit 1
  fi
  log "Colima started successfully."
fi

# Check if Stremio is responsive
if check_stremio; then
  log "Stremio is healthy."
  exit 0
fi

# Stremio is unresponsive — try docker compose restart first
log "WARNING: Stremio is unresponsive. Attempting docker compose restart..."
docker compose -f "$COMPOSE_DIR/docker-compose.yml" restart stremio
sleep 15

if check_stremio; then
  log "Stremio recovered after docker compose restart."
  exit 0
fi

# Still down — full Colima restart as last resort
log "WARNING: Stremio still unresponsive after compose restart. Restarting Colima..."
colima stop
sleep 5
colima start
sleep 15

# Bring up containers after Colima restart
docker compose -f "$COMPOSE_DIR/docker-compose.yml" up -d
sleep 15

if check_stremio; then
  log "Stremio recovered after full Colima restart."
  exit 0
fi

log "ERROR: Stremio is still unresponsive after all recovery attempts."
exit 1
