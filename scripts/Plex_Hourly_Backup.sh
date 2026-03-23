#!/bin/bash

# ============================================================
# Plex Ultra-Fast Hourly Backup (WAL Snapshot Method)
# ------------------------------------------------------------
# - Hot backup (no Plex downtime)
# - Uses SQLite WAL for consistency
# - 24-hour rotation (one snapshot per hour)
# - Atomic snapshot swap
# ============================================================

set -euo pipefail

# -----------------------------
# USER CONFIGURATION
# -----------------------------

PLEX_CONTAINER="plex"

DB_HOST="/mnt/mediacache/plexdata/plex/config/Library/Application Support/Plex Media Server/Plug-in Support/Databases"
PREF_FILE="/mnt/mediacache/plexdata/plex/config/Library/Application Support/Plex Media Server/Preferences.xml"

BASE_DEST="/mnt/cache/BackupForMediacache/Backups/PlexDatabase/hourly"

NOTIFY_ENABLED="true"

# -----------------------------
# PRE-FLIGHT CHECKS
# -----------------------------

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is required"; exit 1; }
[ -d "$DB_HOST" ] || { echo "ERROR: DB path not found: $DB_HOST"; exit 1; }

# -----------------------------
# RUNTIME SETUP
# -----------------------------

START_TIME=$(date +%s)
HOUR=$(date +%H)

TMP_DEST="$BASE_DEST/.tmp_$HOUR"
DEST="$BASE_DEST/$HOUR"

# Cleanup temp folder on exit (even on failure)
cleanup() {
  rm -rf "$TMP_DEST"
}
trap cleanup EXIT

# -----------------------------
# LOGGING / NOTIFICATIONS
# -----------------------------

log(){
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PlexHourlyBackup] $1"
}

notify(){
  if [ "$NOTIFY_ENABLED" = "true" ]; then
    /usr/local/emhttp/webGui/scripts/notify \
      -s "Plex Hourly Backup" \
      -d "$1" \
      -i "normal"
  fi
}

# -----------------------------
# START BACKUP
# -----------------------------

log "Starting snapshot for hour $HOUR"

rm -rf "$TMP_DEST"
mkdir -p "$TMP_DEST"

# -----------------------------
# WAL CHECKPOINT (non-blocking)
# -----------------------------

docker exec "$PLEX_CONTAINER" \
  "/usr/lib/plexmediaserver/Plex SQLite" \
  "/config/Library/Application Support/Plex Media Server/Plug-in Support/Databases/com.plexapp.plugins.library.db" \
  "PRAGMA wal_checkpoint(PASSIVE);" \
  >/dev/null 2>&1 || log "Warning: WAL checkpoint failed (continuing)"

# -----------------------------
# COPY DATABASE FILE SETS
# -----------------------------

copy_db_set() {
  local name="$1"

  cp -f "$DB_HOST/$name" "$TMP_DEST/"
  cp -f "$DB_HOST/$name-wal" "$TMP_DEST/" 2>/dev/null || true
  cp -f "$DB_HOST/$name-shm" "$TMP_DEST/" 2>/dev/null || true
}

# Main databases
copy_db_set "com.plexapp.plugins.library.db"
copy_db_set "com.plexapp.plugins.library.blobs.db"

# Optional settings DB
if [ -f "$DB_HOST/com.plexapp.plugins.library.settings.db" ]; then
  cp -f "$DB_HOST/com.plexapp.plugins.library.settings.db" "$TMP_DEST/"
fi

# Preferences
cp -f "$PREF_FILE" "$TMP_DEST/"

# -----------------------------
# ATOMIC SNAPSHOT SWAP
# -----------------------------

rm -rf "$DEST"
mv -T "$TMP_DEST" "$DEST"

log "Snapshot complete for hour $HOUR"

notify "Plex hourly snapshot completed successfully"

# -----------------------------
# TIMING
# -----------------------------

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

log "Execution time: $((DURATION / 60))m ${DURATION}s"
