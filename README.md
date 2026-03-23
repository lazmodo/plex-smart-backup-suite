# Plex Smart Backup Suite

Fast, WAL-safe Plex backups with hourly snapshots, GFS rotation, and validated restore scripts.

---

## 🚀 Features

* ⚡ Ultra-fast hourly backups (1–3 seconds)
* 🔒 SQLite WAL-safe (no corruption, no downtime)
* ✅ Automatic validation before restore
* 🛟 Emergency rollback protection
* 🐳 Designed for Docker + Unraid

---

## 📦 Included Scripts

| Script                    | Purpose                                    |
| ------------------------- | ------------------------------------------ |
| Plex-Hourly-Backup.sh     | Creates rolling hourly snapshots           |
| Plex_Hourly_Restore.sh    | Finds and restores the newest valid backup |


---

## ⚡ Quick Start

1. Edit configuration at the top of each script

2. Run manually:

```bash
./plex-hourly-backup.sh
```

3. Schedule (recommended):

* Hourly backups

---

## ⏱ Recommended Schedule

```cron
# Hourly snapshots
0 * * * *

```

---

## 🧠 Why This Works

Plex uses SQLite with Write-Ahead Logging (WAL).

This suite safely backs up:

* `.db`
* `-wal`
* `-shm`

Together, these create a **consistent live snapshot**, without stopping Plex.

---

## 📂 Backup Strategy

* Hourly → fast recovery (last 24 hours)
* Restore script → automatic validation + fallback

See `/docs/BACKUP_STRATEGY.md` for details.

---

## ⚠️ Important Notes

* Do NOT remove WAL files (`-wal`, `-shm`)
* Do NOT stop Plex for backups
* Do NOT rely on `.db` alone

---

## 📖 Documentation

* docs/HOW_IT_WORKS.md
* docs/RESTORE_GUIDE.md
* docs/BACKUP_STRATEGY.md

---

## 🧩 Unraid Setup

See: `examples/unraid-user-scripts.md`

---

## 📜 License

MIT
