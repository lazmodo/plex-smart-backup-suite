#!/bin/bash

# ============================================================
# Plex Targeted Restore Helper
# ------------------------------------------------------------
# - Select specific hourly or GFS backup
# - Supports CLI args OR config variables
# - Prepares snapshot for restore scripts
# ============================================================

set -euo pipefail

# -----------------------------
# USER CONFIGURATION
# -----------------------------

PLEX_CONTAINER="plex"

BACKUP_ROOT="/mnt/cache/BackupForMediacache/Backups/PlexDatabase"
HOURLY_DIR="$BACKUP_ROOT/hourly"
DAILY_DIR="$BACKUP_ROOT/daily"

TMP_DIR="/tmp/plex_restore_test"

# Optional: set defaults for User Scripts
DEFAULT_MODE=""        # "hourly" or "daily"
DEFAULT_TARGET=""      # e.g. "14" or "plex-db-2026-03-23.tar"

# -----------------------------
# LOGGING / ERROR HANDLING
# -----------------------------

log(){
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PlexRestoreSelect] $1"
}

trap 'log "ERROR at line $LINENO: command \"${BASH_COMMAND}\" failed"' ERR

# -----------------------------
# CLEANUP HANDLER
# -----------------------------

cleanup(){
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# -----------------------------
# INPUT HANDLING
# -----------------------------

MODE="${1:-$DEFAULT_MODE}"
TARGET="${2:-$DEFAULT_TARGET}"

if [[ -z "$MODE" || -z "$TARGET" ]]; then
  echo "Usage:"
  echo "./plex-restore-specific.sh hourly 14"
  echo "./plex-restore-specific.sh daily plex-db-YYYY-MM-DD.tar"
  echo ""
  echo "Or set DEFAULT_MODE and DEFAULT_TARGET in script."
  exit 1
fi

# -----------------------------
# PROCESS
# -----------------------------

log "Mode: $MODE"
log "Target: $TARGET"

case "$MODE" in

  hourly)
    DIR="$HOURLY_DIR/$TARGET"

    if [[ ! -d "$DIR" ]]; then
      log "ERROR: Hourly snapshot not found: $DIR"
      exit 1
    fi

    ;;

  daily)

    ARCHIVE="$DAILY_DIR/$TARGET"

    if [[ ! -f "$ARCHIVE" ]]; then
      log "ERROR: Archive not found: $ARCHIVE"
      exit 1
    fi

    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"

    log "Extracting $ARCHIVE"
    tar -xf "$ARCHIVE" -C "$TMP_DIR"

    DIR="$TMP_DIR"
    ;;

  *)
    log "Invalid mode: $MODE"
    echo "Valid modes: hourly, daily"
    exit 1
    ;;

esac

# -----------------------------
# RESULT
# -----------------------------

log "Snapshot prepared at: $DIR"

# Optional: you could echo this for chaining into other scripts
echo "$DIR"
