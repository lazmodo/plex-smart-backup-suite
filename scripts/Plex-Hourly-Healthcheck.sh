#!/bin/bash

# ============================================================
# Plex Hourly Backup Health Check
# ------------------------------------------------------------
# - Validates all 24 hourly snapshots
# - Uses SQLite integrity checks
# - Reports failures and summary
# - Runs once a day to verify all hourly backups are healthy
# ============================================================

set -euo pipefail

log(){
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PlexHealth] $1"
}

trap 'log "ERROR at line $LINENO: command \"${BASH_COMMAND}\" failed"' ERR

# -----------------------------
# USER CONFIGURATION
# -----------------------------

PLEX_CONTAINER="plex"

HOURLY_DIR="/mnt/cache/BackupForMediacache/Backups/PlexDatabase/hourly"

SQLITE_BIN="/usr/lib/plexmediaserver/Plex SQLite"

TMP_DIR="/tmp/plex_backup_test"

# Notification behavior
NOTIFY_ON_SUCCESS=false
ENABLE_NOTIFICATIONS=true

# -----------------------------
# LOGGING / ERROR HANDLING
# -----------------------------

log(){
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PlexHealth] $1"
}

trap 'log "ERROR at line $LINENO: command \"${BASH_COMMAND}\" failed"' ERR

notify(){
  if [ "$ENABLE_NOTIFICATIONS" = true ]; then
    /usr/local/emhttp/webGui/scripts/notify \
      -s "Plex Backup Health Check" \
      -d "$1" \
      -i "normal"
  fi
}

# -----------------------------
# CLEANUP HANDLER
# -----------------------------

cleanup(){
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# -----------------------------
# DATABASE VALIDATION
# -----------------------------

validate_db(){
  local DB="$1"

  local RESULT
  RESULT=$(docker exec "$PLEX_CONTAINER" "$SQLITE_BIN" "$DB" "PRAGMA quick_check;" 2>/dev/null) || return 1
  [[ "$RESULT" == "ok" ]] || return 1

  RESULT=$(docker exec "$PLEX_CONTAINER" "$SQLITE_BIN" "$DB" "PRAGMA integrity_check;" 2>/dev/null) || return 1
  [[ "$RESULT" == "ok" ]]
}

# -----------------------------
# START
# -----------------------------

START_TIME=$(date +%s)

log "Starting hourly backup validation"

FAILURES=()
SUCCESS_COUNT=0

# -----------------------------
# VALIDATION LOOP
# -----------------------------

for HOUR in $(seq -w 00 23); do

  DIR="$HOURLY_DIR/$HOUR"

  if [[ ! -d "$DIR" ]]; then
    FAILURES+=("Hour $HOUR: Missing directory")
    continue
  fi

  if [[ ! -f "$DIR/com.plexapp.plugins.library.db" ]]; then
    FAILURES+=("Hour $HOUR: Missing library.db")
    continue
  fi

  log "Testing hour $HOUR"

  rm -rf "$TMP_DIR"
  mkdir -p "$TMP_DIR"

  cp "$DIR"/com.plexapp.plugins.library* "$TMP_DIR"/ 2>/dev/null || true
  cp "$DIR"/com.plexapp.plugins.library.blobs* "$TMP_DIR"/ 2>/dev/null || true
  cp "$DIR"/com.plexapp.plugins.library.settings* "$TMP_DIR"/ 2>/dev/null || true

  docker cp "$TMP_DIR/." "$PLEX_CONTAINER":/tmp/plexrestore >/dev/null 2>&1 || {
    FAILURES+=("Hour $HOUR: docker copy failed")
    continue
  }

  if ! validate_db "/tmp/plexrestore/com.plexapp.plugins.library.db"; then
    FAILURES+=("Hour $HOUR: library.db failed")
    continue
  fi

  if ! validate_db "/tmp/plexrestore/com.plexapp.plugins.library.blobs.db"; then
    FAILURES+=("Hour $HOUR: blobs.db failed")
    continue
  fi

  SUCCESS_COUNT=$((SUCCESS_COUNT+1))

done

# -----------------------------
# RESULTS
# -----------------------------

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

if [ ${#FAILURES[@]} -gt 0 ]; then

  log "Failures detected"

  MESSAGE="Backup issues detected:\n"

  for f in "${FAILURES[@]}"; do
    MESSAGE+="$f\n"
  done

  MESSAGE+="Valid snapshots: $SUCCESS_COUNT / 24"

  notify "$MESSAGE"

  log "Execution time: $((DURATION / 60))m ${DURATION}s"

  exit 1

else

  log "All hourly backups are valid ($SUCCESS_COUNT/24)"

  if [ "$NOTIFY_ON_SUCCESS" = true ]; then
    notify "All 24 hourly Plex backups validated successfully"
  fi

  log "Execution time: $((DURATION / 60))m ${DURATION}s"

  exit 0

fi
