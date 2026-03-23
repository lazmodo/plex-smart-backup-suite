# Restore Guide

## 🔁 Automatic Restore (Recommended)

Run:

```bash
./plex-restore-validated.sh
```

This script will:

* Scan hourly backups (newest → oldest)
* Validate each snapshot using SQLite integrity checks
* Restore the first valid backup found
* Create an emergency backup before making changes

---

## 🧪 Dry Run Mode

The default mode. To test without making any changes, enable dry run:

```bash
DRY_RUN=true
```

This will:

* Perform validation checks
* Show which snapshot *would* be restored
* Exit safely without modifying anything

---

## 🛠 Manual Restore

If you prefer to restore manually:

1. **Stop Plex**
2. Copy backup files into:

   ```
   Plug-in Support/Databases
   ```
3. Restore:

   * `com.plexapp.plugins.library.db`
   * `com.plexapp.plugins.library.db-wal`
   * `com.plexapp.plugins.library.db-shm`
   * `com.plexapp.plugins.library.blobs.db`
   * (and related WAL/SHM files if present)
4. Restore `Preferences.xml`
5. **Start Plex**

---

## 🛟 Emergency Backup

Before restoring, the script automatically creates a backup of your current state:

```
Backups/PlexDatabase/emergency/
```

This allows you to roll back if needed.

---

## ⚠️ Important Notes

* Always restore **all related WAL files** (`-wal`, `-shm`)
* Do not restore only the `.db` file
* Ensure Plex is **stopped** before manual restore
* WAL checkpointing is handled automatically by the script

---

## 🧠 How Validation Works

Each snapshot is tested using:

* `PRAGMA quick_check;`
* `PRAGMA integrity_check;`

A backup is only used if **both checks return `ok`**, ensuring database consistency.

---

## ❗ Troubleshooting

### No valid snapshot found

* Check that backups exist in the hourly directory
* Verify backup script is running successfully
* Inspect logs for validation failures

### Plex fails to start after restore

* Restore from a different (older) snapshot
* Check file permissions
* Verify all WAL files were restored

---

## 🔄 Recommended Workflow

1. Run restore script (dry run first)
2. Confirm selected snapshot
3. Run actual restore
4. Verify Plex starts correctly
5. Spot-check library integrity

---
