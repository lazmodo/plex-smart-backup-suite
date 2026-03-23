#!/bin/bash

# ============================================================
# Plex Smart Restore Script (Validated + Fallback Scan)
# ------------------------------------------------------------
# - Scans hourly backups (newest → oldest)
# - Validates SQLite integrity before restore
# - Creates emergency pre-restore backup
# - Optional WAL truncate safety pass
# ============================================================

set -euo pipefail

# -----------------------------
# USER CONFIGURATION
# -----------------------------

PLEX_CONTAINER="plex"

BACKUP_ROOT="/mnt/cache/BackupForMediacache/Backups/PlexDatabase"
HOURLY_DIR="$BACKUP_ROOT/hourly"
EMERGENCY_DIR="$BACKUP_ROOT/emergency"

PLEX_ROOT="/mnt/mediacache/plexdata/plex/config/Library/Application Support/Plex Media Server"
DB_DIR="$PLEX_ROOT/Plug-in Support/Databases"
PREF_FILE="$PLEX_ROOT/Preferences.xml"

SQLITE_BIN="/usr/lib/plexmediaserver/Plex SQLite"

# Determines which backup folder to check first
HOURLY_BACKUP_MINUTE=33

#Dry run to test it would capture correct file. Change to false when you want restore.
DRY_RUN=true                 # true = validation only
ENABLE_WAL_TRUNCATE=true    # run TRUNCATE checkpoint after restore
ENABLE_NOTIFICATIONS=true

TMP_DIR="/tmp/plex_restore_test"

# -----------------------------
# PRE-FLIGHT CHECKS
# -----------------------------

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is required"; exit 1; }
[ -d "$HOURLY_DIR" ] || { echo "ERROR: Hourly backup directory not found"; exit 1; }

# -----------------------------
# CLEANUP HANDLER
# -----------------------------

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# -----------------------------
# LOGGING / NOTIFICATIONS
# -----------------------------

log(){
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PlexRestore] $1"
}

notify(){
  if [ "$ENABLE_NOTIFICATIONS" = true ]; then
    /usr/local/emhttp/webGui/scripts/notify \
      -s "Plex Restore" \
      -d "$1" \
      -i "normal"
  fi
}

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
# DETERMINE START HOUR
# -----------------------------

CURRENT_HOUR=$(date +%H)
CURRENT_MINUTE=$(date +%M)

if (( CURRENT_MINUTE < HOURLY_BACKUP_MINUTE )); then
  START_HOUR=$((10#$CURRENT_HOUR - 1))
else
  START_HOUR=$((10#$CURRENT_HOUR))
fi

START_HOUR=$(( (START_HOUR + 24) % 24 ))

log "Starting hourly scan at hour $START_HOUR"

# -----------------------------
# SCAN HOURLY BACKUPS
# -----------------------------

for ((i=0;i<24;i++)); do

  HOUR=$(printf "%02d" $(( (START_HOUR - i + 24) % 24 )))
  DIR="$HOURLY_DIR/$HOUR"

  [[ -d "$DIR" ]] || continue
  [[ -f "$DIR/com.plexapp.plugins.library.db" ]] || continue

  log "Testing snapshot $HOUR"

  rm -rf "$TMP_DIR"
  mkdir -p "$TMP_DIR"

  cp "$DIR"/com.plexapp.plugins.library* "$TMP_DIR"/ 2>/dev/null || true
  cp "$DIR"/com.plexapp.plugins.library.blobs* "$TMP_DIR"/ 2>/dev/null || true
  cp "$DIR"/com.plexapp.plugins.library.settings* "$TMP_DIR"/ 2>/dev/null || true
  cp "$DIR"/Preferences.xml "$TMP_DIR"/ 2>/dev/null || true

  docker cp "$TMP_DIR/." "$PLEX_CONTAINER":/tmp/plexrestore >/dev/null 2>&1

  if ! validate_db "/tmp/plexrestore/com.plexapp.plugins.library.db"; then
    log "library.db failed validation"
    continue
  fi

  if ! validate_db "/tmp/plexrestore/com.plexapp.plugins.library.blobs.db"; then
    log "blobs.db failed validation"
    continue
  fi

  # -----------------------------
  # DRY RUN MODE
  # -----------------------------

  if [[ "$DRY_RUN" = true ]]; then
    log "DRY RUN: snapshot $HOUR would be restored"
    exit 0
  fi

  # -----------------------------
  # STOP PLEX
  # -----------------------------

  log "Stopping Plex"
  docker stop "$PLEX_CONTAINER"

  # -----------------------------
  # EMERGENCY BACKUP
  # -----------------------------

  TIMESTAMP=$(date +"%F-%H%M")
  mkdir -p "$EMERGENCY_DIR"

  tar -cf "$EMERGENCY_DIR/plex-pre-restore-$TIMESTAMP.tar" \
    "$DB_DIR"/com.plexapp.plugins.library* \
    "$DB_DIR"/com.plexapp.plugins.library.blobs* \
    "$DB_DIR"/com.plexapp.plugins.library.settings* \
    "$PREF_FILE" 2>/dev/null || true

  # -----------------------------
  # RESTORE SNAPSHOT
  # -----------------------------

  log "Restoring snapshot $HOUR"

  cp "$DIR"/com.plexapp.plugins.library* "$DB_DIR"/
  cp "$DIR"/com.plexapp.plugins.library.blobs* "$DB_DIR"/
  cp "$DIR"/com.plexapp.plugins.library.settings* "$DB_DIR"/ 2>/dev/null || true
  cp "$DIR"/Preferences.xml "$PREF_FILE"

  # -----------------------------
  # WAL CHECKPOINT SAFETY
  # -----------------------------

  if [[ "$ENABLE_WAL_TRUNCATE" = true ]]; then
    docker start "$PLEX_CONTAINER"

    docker exec "$PLEX_CONTAINER" "$SQLITE_BIN" \
      "/config/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db" \
      "PRAGMA wal_checkpoint(TRUNCATE);" || true

    docker exec "$PLEX_CONTAINER" "$SQLITE_BIN" \
      "/config/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.blobs.db" \
      "PRAGMA wal_checkpoint(TRUNCATE);" || true

    docker exec "$PLEX_CONTAINER" "$SQLITE_BIN" \
      "/config/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.settings.db" \
      "PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null || true

    docker stop "$PLEX_CONTAINER"
  fi

  # -----------------------------
  # START PLEX
  # -----------------------------

  docker start "$PLEX_CONTAINER"

  log "Restore completed from hourly snapshot $HOUR"
  notify "Plex restored from hourly snapshot $HOUR"

  exit 0

done

# -----------------------------
# FAILURE
# -----------------------------

log "No valid hourly snapshot found"
notify "No valid hourly snapshot found"

exit 1
