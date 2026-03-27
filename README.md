# Plex Smart Backup Suite
[![Unraid Compatible](https://img.shields.io/badge/Unraid-Compatible-green?logo=unraid)](https://unraid.net/)
[![Version](https://img.shields.io/badge/Version-2026.03.23-green.svg)](https://github.com/lazmodo/plex-smart-backup-suite/releases)

Fast, WAL-safe Plex DB backups with hourly snapshots, GFS rotation, and validated restore scripts. It is designed to have the plexdata and backup folders on SSDs. 

---

## 🚀 Features

* ⚡ **Ultra-fast hourly backups** (WAL snapshot method, no downtime)
* 🗓️ **GFS rotation backups** (Daily / Weekly / Monthly using SQLite `.backup`)
* 🔍 **Automated backup validation**

  * Hourly snapshot validation (daily health check)
  * Restore-time integrity verification
* 🔄 **Multiple restore options**

  * Auto-restore from latest valid snapshot
  * Restore from GFS archives
  * Targeted restore (specific hour or archive)
* 🛟 **Built-in safety mechanisms**

  * Pre-restore emergency backups
  * SQLite integrity checks
  * Optional WAL checkpointing
* 🔔 Optional Unraid notifications
* 🧩 Modular scripts (use independently or together)

---

## 📂 Scripts Overview

### 🔁 Hourly Backups

| Script                      | Description                                              |
| --------------------------- | -------------------------------------------------------- |
| `Plex_Hourly_Backup.sh`     | Creates fast hourly database snapshots using WAL         |
| `Plex_Hourly_Restore.sh` | Automatically restores from latest valid hourly snapshot |

---

### 🗄️ GFS Backups (Daily / Weekly / Monthly)

| Script                 | Description                                                                            |
| ---------------------- | -------------------------------------------------------------------------------------- |
| `Plex_Daily_Backups.sh` | Creates compressed daily backups using SQLite `.backup`, with weekly/monthly promotion |
| `Plex_Daily_Restore.sh`  | Scans and restores from the latest valid GFS archive                                   |

---

### 🔍 Backup Validation

| Script                       | Description                                                   |
| ---------------------------- | ------------------------------------------------------------- |
| `Plex-Hourly-Healthcheck.sh` | Validates all 24 hourly backups using SQLite integrity checks |

---

### 🎯 Targeted Restore Tools

| Script                     | Description                                                                    |
| -------------------------- | ------------------------------------------------------------------------------ |
| `Plex-Restore-Specific.sh` | Selects and prepares a specific backup (hourly or daily) for restore workflows |

---

## 📂 Backup Strategy

This project implements a **layered backup approach**:

* **Hourly snapshots**

  * Fast, lightweight, near real-time recovery
   
* **Daily GFS backups**
  * Reliable, portable, long-term storage

* **Validation layer**
  * Ensures backups are actually usable before restore

> Plex does not provide a complete backup system out of the box, so combining multiple strategies is essential for reliable recovery. ([GitHub][1])

See [Backup Strategy](/docs/BACKUP_STRATEGY.md) for details.

---

## 🔄 Example Workflows

### Hourly Recovery (Fastest)

```bash
Plex_Hourly_Restore.sh
```

---

### Restore from Daily Backup

```bash
Plex_Daily_Restore.sh
```

---

### Restore Specific Backup

```bash
Plex-Restore-Specific.sh hourly 14
Plex-Restore-Specific.sh daily plex-db-2026-03-23.tar
```

---

### Validate Backups

```bash
Plex-Hourly-Healthcheck.sh
```

---

## ⚙️ Usage (Unraid)

All scripts are designed to run via:

* User Scripts plugin
* Cron jobs
* Manual execution

Each script includes a **USER CONFIGURATION section at the top** for easy setup.

---

## ⚠️ Notes

* Scripts assume Docker-based Plex installation
* Designed for Unraid paths (can be adapted)
* Always test restores before relying on backups

---

## 📌 Roadmap

* Unified restore script (hourly + GFS fallback)
* Optional interactive restore selector
* Backup monitoring / reporting enhancements



---

## ⚡ Quick Start

### 1️⃣ Configure Scripts

Edit the **USER CONFIGURATION** section at the top of each script:

* Set your Plex paths
* Confirm container name (`plex`)
* Adjust backup locations if needed

---

### 2️⃣ Test Manually (Recommended)

Run each script once to confirm everything works:

```bash
./scripts/Plex_Hourly_Backup.sh
./scripts/Plex_Daily_Backups.sh
./scripts/Plex-Hourly-Healthcheck.sh
```

Test restore (safe mode):

```bash
./scripts/Plex_Hourly_Restore.sh   # Hourly (DRY_RUN=true) will look at most recent backup and work backwards looking for a valid backup. DryRun will state the most recent backup.
./scripts/Plex_Daily_Restore.sh         # GFS restore (DRY_RUN=true) will look at most recent backup and work backwards looking for a valid backup.DryRun will state the most recent backup.
```

---

### 3️⃣ Schedule Jobs (Unraid User Scripts or Cron)

#### ⏱ Recommended Schedule

```cron
# Hourly snapshots (fast recovery)
33 * * * * /path/to/scripts/Plex_Hourly_Backup.sh

# Daily GFS backup (long-term retention)
30 3 * * * /path/to/scripts/Plex_Daily_Backups.sh

# Daily health check (validate all hourly backups). If these are good, then the GFS backups should be good.
0 6 * * * /path/to/scripts/Plex-Hourly-Healthcheck.sh
```

---

### 4️⃣ Verify Backups

* Check backup directories:

  * `hourly/`
  * `daily/`, `weekly/`, `monthly/`
* Review logs for errors
* Confirm health check reports **24/24 valid snapshots**

---

### 5️⃣ Perform a Test Restore (Highly Recommended)

Dry run:

```bash
./scripts/Plex_Daily_Restore.sh
```

Actual restore:

```bash
# Edit script first:
DRY_RUN=false
```

---

## 🧠 Recommended Setup

| Layer           | Purpose                           |
| --------------- | --------------------------------- |
| Hourly Backups  | Fast recovery (minimal data loss) |
| GFS Backups     | Long-term protection              |
| Health Check    | Ensures backups are valid         |
| Restore Scripts | Safe recovery with validation     |

---

## ⚠️ Important

* Always test restore before relying on backups
* Keep backups on a different disk if possible
* Monitor logs or enable notifications for failures


---

## 🧠 Why This Works

Plex uses SQLite with Write-Ahead Logging (WAL).

This suite safely backs up:

* `.db`
* `-wal`
* `-shm`

Together, these create a **consistent live snapshot**, without stopping Plex.

---

## ⚠️ Important Notes

* Do NOT remove WAL files (`-wal`, `-shm`)
* Do NOT stop Plex for backups
* Do NOT rely on `.db` alone

---

## 📖 Documentation

* `docs/HOW_IT_WORKS.md` - Technical explanation
* `docs/RESTORE_GUIDE.md` - How to restore
* `docs/User-Scripts-Setup.md` - Unraid-specific setup

---

## 🧩 Unraid Setup

See: `examples/unraid-user-scripts.md`

---

## 📜 License

MIT
