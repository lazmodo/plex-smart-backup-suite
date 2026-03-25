# 🧠 How It Works

This project provides a **layered Plex DB backup and recovery system** designed for speed, reliability, and safety.

---

## 🔄 System Overview

The system is built on three core layers:

1. **Hourly Backups (Fast Recovery)**
2. **GFS Backups (Long-Term Protection)**
3. **Validation & Restore (Reliability)**

---

## ⚡ 1. Hourly Backups

**Script:** `Plex_Hourly_Backup.sh`

### 🔹 How it works:

* Runs every hour
* Performs a **WAL checkpoint (PASSIVE)** to stabilize writes
* Copies:

  * `library.db`
  * `blobs.db`
  * `settings.db`
  * WAL + SHM files (if present)
  * `Preferences.xml`
* Stores snapshots in:

```
/hourly/00 → 23
```

### ✅ Benefits:

* Extremely fast (~1–2 seconds)
* No Plex downtime
* Near real-time recovery capability

---

## 🗄️ 2. GFS Backups (Daily / Weekly / Monthly)

**Script:** `Plex_Daily_Backups.sh`

### 🔹 How it works:

* Runs daily
* Uses SQLite `.backup` for **clean, consistent database copies**
* Creates:

  * Daily backups
  * Weekly backups (every Sunday)
  * Monthly backups (1st of month)

### 📂 Structure:

```
/daily/
/weekly/
/monthly/
```

### ✅ Benefits:

* Reliable long-term storage
* Portable `.tar` archives
* Independent of WAL state

---

## 🔍 3. Backup Validation

**Script:** `Plex-Hourly-Healthcheck.sh`

### 🔹 How it works:

* Scans all 24 hourly backups
* Runs:

  * `PRAGMA quick_check`
  * `PRAGMA integrity_check`
* Reports:

  * Missing backups
  * Corrupted databases

### 🔔 Notifications

* Sends an Unraid notification **only if failures are detected**
* Optional success notifications can be enabled in the script:

  ```bash
  NOTIFY_ON_SUCCESS=true
  ```

> Notifications are controlled via the `ENABLE_NOTIFICATIONS` and `NOTIFY_ON_SUCCESS` settings in the script.

### ✅ Benefits:

* Ensures backups are actually usable
* Detects corruption early
* Prevents bad restores
* Provides proactive alerting when issues occur

---

## 🔄 4. Restore System

There are **multiple restore paths**, all with built-in safety.

---

### ⚡ Hourly Restore

**Script:** `Plex_Hourly_Restore.sh`

* Scans hourly backups (newest → oldest)
* Validates each snapshot
* Restores the first valid one

---

### 🗄️ Daily Restore (GFS)

**Script:** `Plex_Daily_Restore.sh`

* Extracts `.tar` archives
* Validates before restore
* Restores the newest valid backup

---

### 🎯 Targeted Restore

**Script:** `Plex-Restore-Specific.sh`

* Selects a specific backup:

  * Hourly (by hour)
  * Daily (by filename)
* Prepares it for restore scripts

> Note: This script does not perform the restore itself.

---

## 🛟 5. Safety Features

### 🔒 Emergency Backup

Before any restore:

* Current database is archived to:

```
/emergency/
```

---

### 🔍 Integrity Checks

Every restore includes:

* `quick_check`
* `integrity_check`

---

### 🔄 WAL Checkpointing

Optional:

* Truncates WAL files after restore
* Prevents database bloat

---

## 🔁 Full Workflow

### 📦 Backup Flow

1. Hourly script creates snapshots
2. Daily script creates GFS backups
3. Health check validates hourly backups

---

### 🔄 Restore Flow

1. Restore script scans backups
2. Validates each candidate
3. Stops Plex
4. Creates emergency backup
5. Restores database files
6. Starts Plex
7. (Optional) WAL truncate

---

## 🧠 Why This Approach Works

Plex does not provide a complete backup system by default.

This solution combines:

| Layer         | Purpose             |
| ------------- | ------------------- |
| Hourly        | Fast recovery       |
| GFS           | Long-term retention |
| Validation    | Reliability         |
| Restore Logic | Safe recovery       |

---

## ⚠️ Key Design Principles

* **Never trust a backup without validation**
* **Always keep a rollback option (emergency backup)**
* **Separate fast vs long-term backups**
* **Automate everything possible**

---

## 🚀 Summary

This system ensures:

* Minimal data loss (hourly snapshots)
* Long-term protection (GFS backups)
* Verified recoverability & notification if backup has issue (health checks)
* Safe restores (validated + rollback)

Together, these provide a **complete Plex backup and recovery solution**
