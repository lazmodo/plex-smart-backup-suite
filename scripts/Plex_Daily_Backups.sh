#!/bin/bash

# ============================================================
# Plex GFS Backup Script (SQLite .backup Method)
# ------------------------------------------------------------
# - Creates daily backups using SQLite .backup
# - Promotes to weekly / monthly (GFS rotation)
# - Includes integrity checks before backup
# - Designed for long-term retention
# ============================================================

set -euo pipefail
trap 'log "ERROR at line $LINENO"' ERR

# -----------------------------
# USER CONFIGURATION
# -----------------------------

PLEX_CONTAINER="plex"

HOST_PLEX_ROOT="/mnt/mediacache/plexdata/plex/config/Library/Application Support/Plex Media Server"
HOST_PREF_FILE="$HOST_PLEX_ROOT/Preferences.xml"

CONT_DB_DIR="/config/Library/Application Support/Plex Media Server/Plug-in Support/Databases"

DEST="/mnt/cache/BackupForMediacache/Backups/PlexDatabase"

TMP_ROOT="/mnt/mediacache/plexdata/plex/config/temp_backup"

SQLITE_BIN="/usr/lib/plexmediaserver/Plex SQLite"

# Retention
DAILY_KEEP=7
WEEKLY_KEEP=4
MONTHLY_KEEP=6

# Backup Days 
MONTHLY_DAY=1 #Monthly backup day (1–28 recommended to avoid month-length issues)
WEEKLY_DAY=7  # 1=Monday ... 7=Sunday

# Features
ENABLE_NOTIFICATIONS=true

# -----------------------------
# PRE-FLIGHT CHECKS
# -----------------------------

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is required"; exit 1; }

# -----------------------------
# RUNTIME SETUP
# -----------------------------

START_TIME=$(date +%s)

DATE=$(date +%F)
WEEK=$(date +%G-week%V)
MONTH=$(date +%Y-%m)

TMP_DIR="$TMP_ROOT/tmp_plex_backup_$DATE"



# Cleanup on exit
cleanup_tmp() {
  rm -rf "$TMP_DIR"
}
trap cleanup_tmp EXIT

# -----------------------------
# LOGGING / NOTIFICATIONS
# -----------------------------

log(){
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PlexGFS] $1"
}

notify(){
  if [ "$ENABLE_NOTIFICATIONS" = true ]; then
    /usr/local/emhttp/webGui/scripts/notify \
      -s "Plex Backup" \
      -d "$1" \
      -i "normal"
  fi
}

#Verify monthly day is not an issue
if (( MONTHLY_DAY < 1 || MONTHLY_DAY > 28 )); then
  log "WARNING: MONTHLY_DAY should be between 1 and 28 to avoid month-length issues"
fi
#Verify weekly day is not an issue
if (( WEEKLY_DAY < 1 || WEEKLY_DAY > 7 )); then
  log "WARNING: WEEKLY_DAY must be between 1–7"
else
  WEEKDAY_NAME="${WEEKDAY_NAMES[$((WEEKLY_DAY-1))]}"
  log "Config → WeeklyDay: $WEEKLY_DAY ($WEEKDAY_NAME)"
fi

# -----------------------------
# PREPARE DIRECTORIES
# -----------------------------

mkdir -p "$TMP_DIR"
mkdir -p "$DEST/daily" "$DEST/weekly" "$DEST/monthly"

# Ensure container temp path exists
docker exec "$PLEX_CONTAINER" mkdir -p "/config/temp_backup/tmp_plex_backup_$DATE"

# -----------------------------
# WAL CHECKPOINT (reduce WAL)
# -----------------------------

docker exec "$PLEX_CONTAINER" "$SQLITE_BIN" \
  "$CONT_DB_DIR/com.plexapp.plugins.library.db" \
  "PRAGMA wal_checkpoint(TRUNCATE);" >/dev/null 2>&1 || true

# -----------------------------
# DATABASE VALIDATION
# -----------------------------

check_db(){
  local DB="$1"
  local NAME
  NAME=$(basename "$DB")

  local RESULT
  RESULT=$(docker exec "$PLEX_CONTAINER" "$SQLITE_BIN" "$DB" "PRAGMA quick_check;" 2>/dev/null) || return 1

  if [[ "$RESULT" != "ok" ]]; then
    log "Integrity check failed for $NAME"
    notify "Plex DB quick_check failed for $NAME"
    exit 1
  fi
}

check_db "$CONT_DB_DIR/com.plexapp.plugins.library.db"
check_db "$CONT_DB_DIR/com.plexapp.plugins.library.blobs.db"

if docker exec "$PLEX_CONTAINER" test -f "$CONT_DB_DIR/com.plexapp.plugins.library.settings.db"; then
  check_db "$CONT_DB_DIR/com.plexapp.plugins.library.settings.db"
fi

# -----------------------------
# BACKUP FUNCTION (.backup)
# -----------------------------

backup_db(){
  local SRC="$1"
  local NAME
  NAME=$(basename "$SRC")

  log "Backing up $NAME"

  docker exec "$PLEX_CONTAINER" "$SQLITE_BIN" \
    "$SRC" ".backup '/config/temp_backup/tmp_plex_backup_$DATE/$NAME'"
}

backup_db "$CONT_DB_DIR/com.plexapp.plugins.library.db"
backup_db "$CONT_DB_DIR/com.plexapp.plugins.library.blobs.db"

if docker exec "$PLEX_CONTAINER" test -f "$CONT_DB_DIR/com.plexapp.plugins.library.settings.db"; then
  backup_db "$CONT_DB_DIR/com.plexapp.plugins.library.settings.db"
fi

# -----------------------------
# COPY PREFERENCES
# -----------------------------
log "Copying Preferences.xml"
cp "$HOST_PREF_FILE" "$TMP_DIR/Preferences.xml" 2>/dev/null || \
  log "Warning: Preferences.xml not copied"

# -----------------------------
# CREATE ARCHIVE
# -----------------------------

ARCHIVE="$DEST/daily/plex-db-$DATE.tar"

tar --numeric-owner -cf "$ARCHIVE" -C "$TMP_DIR" .

log "Created $ARCHIVE"

# -----------------------------
# WEEKLY PROMOTION
# -----------------------------

if [[ $(date +%u) -eq "$WEEKLY_DAY" ]]; then
  cp "$ARCHIVE" "$DEST/weekly/plex-db-$WEEK.tar"
  log "Created weekly backup"
fi

# -----------------------------
# MONTHLY PROMOTION
# -----------------------------

DAY_OF_MONTH=$(date +%d)

# Remove leading zero for safe numeric comparison
DAY_OF_MONTH=$((10#$DAY_OF_MONTH))

if [[ "$DAY_OF_MONTH" -eq "$MONTHLY_DAY" ]]; then
  cp "$ARCHIVE" "$DEST/monthly/plex-db-$MONTH.tar"
  log "Created monthly backup"
fi

# -----------------------------
# RETENTION CLEANUP
# -----------------------------

cleanup_old(){
  local DIR="$1"
  local KEEP="$2"

  mapfile -t files < <(ls -1t "$DIR"/*.tar 2>/dev/null || true)

  (( ${#files[@]} > KEEP )) || return 0

  for ((i=KEEP; i<${#files[@]}; i++)); do
    rm -f "${files[i]}"
  done
}

cleanup_old "$DEST/daily" "$DAILY_KEEP"
cleanup_old "$DEST/weekly" "$WEEKLY_KEEP"
cleanup_old "$DEST/monthly" "$MONTHLY_KEEP"

# -----------------------------
# COMPLETE
# -----------------------------

log "Backup complete"
notify "Plex database backup completed successfully"

finish(){
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))

  log "Execution time: $((DURATION / 60))m ${DURATION}s"
}

trap 'finish; cleanup_tmp' EXIT
