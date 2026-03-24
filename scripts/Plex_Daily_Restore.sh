#!/bin/bash

# ============================================================
# Plex GFS Restore Script (Validated Archive Restore)
# ------------------------------------------------------------
# - Scans daily backups (newest → oldest)
# - Validates SQLite integrity before restore
# - Creates emergency pre-restore backup
# ============================================================

set -euo pipefail

# -----------------------------
# USER CONFIGURATION
# -----------------------------

PLEX_CONTAINER="plex"

BACKUP_ROOT="/mnt/cache/BackupForMediacache/Backups/PlexDatabase"
DAILY_DIR="$BACKUP_ROOT/daily"
EMERGENCY_DIR="$BACKUP_ROOT/emergency"

PLEX_ROOT="/mnt/mediacache/plexdata/plex/config/Library/Application Support/Plex Media Server"
DB_DIR="$PLEX_ROOT/Plug-in Support/Databases"
PREF_FILE="$PLEX_ROOT/Preferences.xml"

SQLITE_BIN="/usr/lib/plexmediaserver/Plex SQLite"

DRY_RUN=true
ENABLE_WAL_TRUNCATE=true
ENABLE_NOTIFICATIONS=true

TMP_DIR="/tmp/plex_restore_test"

# -----------------------------
# LOGGING / ERROR HANDLING
# -----------------------------

log(){
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PlexGFSRestore] $1"
}

trap 'log "ERROR at line $LINENO: command \"${BASH_COMMAND}\" failed"' ERR

notify(){
  if [ "$ENABLE_NOTIFICATIONS" = true ]; then
    /usr/local/emhttp/webGui/scripts/notify \
      -s "Plex Restore" \
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

log "Starting GFS restore scan"

# Safe file iteration (no ls)
shopt -s nullglob
FILES=("$DAILY_DIR"/*.tar)
shopt -u nullglob

# Sort newest → oldest
IFS=$'\n' FILES=($(ls -1t "${FILES[@]}" 2>/dev/null || true))

for FILE in "${FILES[@]}"; do

  log "Testing archive $FILE"

  rm -rf "$TMP_DIR"
  mkdir -p "$TMP_DIR"

  tar -xf "$FILE" -C "$TMP_DIR" || {
    log "Failed to extract archive"
    continue
  }

  docker cp "$TMP_DIR/." "$PLEX_CONTAINER":/tmp/plexrestore >/dev/null 2>&1 || {
    log "docker copy failed"
    continue
  }

  if ! validate_db "/tmp/plexrestore/com.plexapp.plugins.library.db"; then
    log "library.db failed validation"
    continue
  fi

  if ! validate_db "/tmp/plexrestore/com.plexapp.plugins.library.blobs.db"; then
    log "blobs.db failed validation"
    continue
  fi

  # -----------------------------
  # DRY RUN
  # -----------------------------

  if [[ "$DRY_RUN" = true ]]; then
    log "DRY RUN: $FILE would be restored"

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    log "Execution time: $((DURATION / 60))m ${DURATION}s"

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
    "$PREF_FILE" 2>/dev/null || true

  # -----------------------------
  # RESTORE
  # -----------------------------

  log "Restoring archive $FILE"

  cp "$TMP_DIR"/com.plexapp.plugins.library* "$DB_DIR"/
  cp "$TMP_DIR"/com.plexapp.plugins.library.blobs* "$DB_DIR"/
  cp "$TMP_DIR"/Preferences.xml "$PREF_FILE" 2>/dev/null || true

  docker start "$PLEX_CONTAINER"

  # -----------------------------
  # WAL TRUNCATE (OPTIONAL)
  # -----------------------------

  if [[ "$ENABLE_WAL_TRUNCATE" = true ]]; then

    docker exec "$PLEX_CONTAINER" "$SQLITE_BIN" \
      "/config/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db" \
      "PRAGMA wal_checkpoint(TRUNCATE);" || true

    docker exec "$PLEX_CONTAINER" "$SQLITE_BIN" \
      "/config/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.blobs.db" \
      "PRAGMA wal_checkpoint(TRUNCATE);" || true

  fi

  # -----------------------------
  # COMPLETE
  # -----------------------------

  log "Restore completed from $FILE"
  notify "Plex restored from nightly backup"

  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))
  log "Execution time: $((DURATION / 60))m ${DURATION}s"

  exit 0

done

# -----------------------------
# FAILURE
# -----------------------------

log "No valid nightly backup found"
notify "No valid nightly backup found"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
log "Execution time: $((DURATION / 60))m ${DURATION}s"

exit 1
