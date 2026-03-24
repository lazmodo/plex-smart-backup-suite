# 🔄 Plex Restore Guide

This guide explains how to restore your Plex database using the scripts in this repository.

---

## 🧠 Restore Strategy Overview

There are **three restore methods**, depending on your situation:

| Method                  | Script                     | Use Case                         |
| ----------------------- | -------------------------- | -------------------------------- |
| ⚡ Hourly Restore        | `Plex_Hourly_Restore.sh`   | Fast recovery (most recent data) |
| 🗄️ Daily Restore (GFS) | `Plex_Daily_Restore.sh`    | Corruption or long-term rollback |
| 🎯 Targeted Restore     | `Plex-Restore-Specific.sh` | Restore a specific snapshot      |

---

## ⚡ Hourly Restore (Recommended First)

This is the **fastest and safest recovery option**.

### ▶️ Run:

```bash
./scripts/Plex_Hourly_Restore.sh
```

### ✅ What it does:

* Scans hourly backups (newest → oldest). Ensure the HOURLY_BACKUP_MINUTE variable is set to the minute you run the backups. This ensures the newest is checked first and not last.
* Validates each snapshot (SQLite integrity checks)
* Restores the first valid backup
* Automatically handles:

  * Stopping Plex
  * Emergency backup
  * Restarting Plex

---

## 🗄️ Daily Restore (GFS Backups)

Use this if:

* Hourly backups are corrupted
* You need to roll back further in time

### ▶️ Run:

```bash
./scripts/Plex_Daily_Restore.sh
```

### ✅ What it does:

* Scans daily backups (newest → oldest)
* Extracts archive
* Validates database before restore
* Restores the first valid archive

---

## 🎯 Restore a Specific Backup

Use this when you know exactly what you want to restore. You can either adjust the DEFAULT_MOD & DEFAULT_TARGET if running via UserScripts, or enter at command line

---

### 🔹 Hourly Snapshot

```bash
./scripts/Plex-Restore-Specific.sh hourly 14
```

---

### 🔹 Daily Backup

```bash
./scripts/Plex-Restore-Specific.sh daily plex-db-2026-03-23.tar
```

---

### ⚠️ Important

This script:

* ✔ Prepares the backup
* ✔ Extracts if needed
* ❌ Does NOT perform the restore

After selecting a snapshot, use the appropriate restore script:

```bash
./scripts/Plex_Hourly_Restore.sh
# or
./scripts/Plex_Daily_Restore.sh
```

---

## 🧪 Dry Run Mode (Safe Testing)

All restore scripts support dry-run mode.

Edit the script:

```bash
DRY_RUN=true
```

This will:

* Validate backups
* Show what would be restored
* NOT modify your Plex database

---

## 🛟 Emergency Backup (Automatic)

Before any restore, the hourly & daily scripts both creates a backup:

```
/Backups/PlexDatabase/emergency/
```

This allows you to:

* Roll back if needed
* Recover from failed restore attempts

---

## 🔍 Troubleshooting

### ❌ No valid backup found

* Run:

```bash
./scripts/Plex-Hourly-Healthcheck.sh
```

* Check logs for corruption or missing files

---

### ❌ Restore fails

* Verify container name
* Check database paths
* Ensure permissions are correct

---

### ❌ Plex won't start after restore

* Check logs:

```bash
docker logs plex
```

* Try another backup snapshot

---

## ⚠️ Best Practices

* Always test restores before relying on backups
* Keep backups on a different disk if possible
* Monitor logs or enable notifications
* Run daily health checks

---

## 🧠 Recommended Recovery Order

1. Try **Hourly Restore**
2. Fall back to **Daily Restore**
3. Use **Targeted Restore** if needed

---

## 🚀 Summary

* Hourly backups = fast recovery
* Daily backups = long-term protection
* Validation = reliability

Together, they provide a **complete Plex backup and recovery system**
