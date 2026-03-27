# 📂 Backup Strategy

This document explains the **why** behind the Plex Smart Backup Suite's layered approach, retention policies, and when to use each backup type.

---

## Why Layered Backups?

Plex does not provide a complete, reliable backup system out of the box. Any single backup method has critical limitations:

| Method | Pros | Cons |
|--------|------|------|
| **Hourly Snapshots Only** | Ultra-fast recovery | Limited history (24 hours max) |
| **Daily Backups Only** | Long-term retention | Slower recovery, loses hourly data |
| **WAL-only backups** | Minimal downtime | Not a complete standalone backup (requires WAL + DB consistency) |

**Solution:** Combine all three for a complete backup strategy.

---

## 📦 What IS Backed Up

This system backs up the **core Plex databases and configuration required for a full logical restore**.

### Included Data

* **Primary database**

  * `com.plexapp.plugins.library.db`
* **Blobs database**

  * `com.plexapp.plugins.library.blobs.db`
* **Settings database (if present)**

  * `com.plexapp.plugins.library.settings.db`
* **SQLite WAL/SHM files (hourly backups only)**

  * Ensures consistency during live snapshots
* **Plex Preferences**

  * `Preferences.xml`

The hourly and daily backups both contain the same core data, just stored differently.

---

## ⚠️ What is NOT Backed Up

This backup system focuses on **Plex databases only**.

Not included:
- Media files (movies, shows)
- Thumbnails / preview images
- Metadata artwork (posters, fanart)
- Transcoding cache

> These are stored outside the database and should be backed up separately if needed.

---

## 🔄 The Three Layers

### **Layer 1: Hourly Snapshots (Fast Recovery)**

**Purpose:** Recover from data corruption with minimal data loss.

- **Frequency:** Every hour (24-hour rotation)
- **Method:** WAL snapshot (no Plex downtime)
- **Recovery Time:** ~1-2 minutes
- **Data Loss Risk:** Up to 1 hour
- **Use When:** Recent accidental deletion, metadata corruption in last 24 hours

**Retention:**
- Keeps 24 hourly backups (0-23)
- Oldest backup is automatically overwritten
- No manual cleanup needed

**Example Scenario:**
```
You accidentally deleted a library this morning at 10:00 AM.
Current time: 2:00 PM
Available snapshots: Hours 00-23 (from today + yesterday)
Action: Restore from hour 10 snapshot
Result: Recover deleted library with only 4 hours of new content lost
```

---

### **Layer 2: Daily GFS Backups (Long-Term Protection)**

**Purpose:** Long-term retention with protection against systemic failures.

**GFS = Grandfather-Father-Son** rotation strategy:
- **Daily:** Keep 7 days (one per day)
- **Weekly:** Keep 4 weeks (Sundays only)
- **Monthly:** Keep 6 months (1st of each month)

**Frequency:** Once per day (default: 3:10 AM)

**Method:** SQLite `.backup` command (clean, consistent backups, millisecond-level write locks)

**Recovery Time:** ~5-10 minutes (archive extraction + restore)

**Data Loss Risk:** Up to 24 hours (back to yesterday)

**Use When:**
- Hourly backups are corrupted
- Need to roll back further than 24 hours
- Systemic database corruption detected
- Long-term recovery (weeks or months back)

**Retention Details:**

| Level | Count | Duration | Use Case |
|-------|-------|----------|----------|
| Daily | 7 | 1 week | Week-long rollback |
| Weekly | 4 | ~1 month | Recent month rollback |
| Monthly | 6 | ~6 months | Seasonal/archival rollback |

**Example Scenario:**
```
You want to restore your Plex database from 3 weeks ago.
- Hourly backups: Only have last 24 hours ❌
- Daily backups: Only have last 7 days ❌
- Weekly backups: Have backups from 4 weeks back ✅
Action: Restore from weekly backup dated 3 weeks ago
Result: Recover library state from that date
```

---

### **Layer 3: Validation & Monitoring (Reliability)**

**Purpose:** Ensure backups are actually usable before a disaster forces you to rely on them.

**What Gets Validated:**
- Hourly snapshots (24 per day)
- Daily GFS backups (on creation)

**Validation Methods:**
- `PRAGMA quick_check` - Fast surface-level check
- `PRAGMA integrity_check` - Deep database integrity

**Frequency:** Daily (default: 6:00 AM)

**Notifications:**
- Alerts only on failures (unless enabled otherwise)
- Proactive detection of corruption before you need the backup

**Use When:**
- Scheduled health checks (automated, no action needed)
- Before performing a restore (automatic)
- Troubleshooting backup failures

**Example Scenario:**
```
Health check runs at 6 AM.
Result: "22/24 hourly snapshots valid, 2 corrupted"
Action: Investigate why 2 snapshots failed (permissions? disk space?)
Benefit: You know BEFORE disaster strikes that some backups are bad
```

---

## 📊 Recovery Decision Tree

**Scenario 1: Recent Data Loss (last 24 hours)**
```
Use: Hourly Restore
Why: Fastest, least data loss
Restore time: ~2 minutes
```

**Scenario 2: Corruption Detected**
```
Try: Hourly Restore first
Fallback: Daily Restore
Why: Incremental fallback, best chance of success
```

**Scenario 3: Need to Roll Back Weeks/Months**
```
Use: Weekly or Monthly backup (Daily Restore)
Why: Only option with that much history
Restore time: ~5-10 minutes
```

**Scenario 4: All Backups Corrupted**
```
Last resort: Emergency backup (created before each restore)
Why: Rollback point if restore failed
```

---

## 🔍 When to Adjust Retention

### Increase Retention If:
- You have large storage capacity
- You want 1+ year of backups

**Change in scripts:**
```bash
# In Plex_Daily_Backups.sh
DAILY_KEEP=30      # Keep 30 days instead of 7
WEEKLY_KEEP=12     # Keep 12 weeks instead of 4
MONTHLY_KEEP=12    # Keep 12 months instead of 6
```

### Decrease Retention If:
- Storage is limited
- You don't need historical rollback
- Fast, recent-only recovery is sufficient

**Change in scripts:**
```bash
# In Plex_Daily_Backups.sh
DAILY_KEEP=3       # Keep only 3 days
WEEKLY_KEEP=2      # Keep only 2 weeks
MONTHLY_KEEP=3     # Keep only 3 months
```

---

## 💾 Storage Requirements

### Typical Storage per Backup

Backup size varies by library size:

| Library Size | Approx Items        | Hourly Snapshot (WAL) | Daily Backup (.backup) |
| ------------ | ------------------- | --------------------- | ---------------------- |
| Small        | < 2,000 items       | 50–150 MB             | 40–120 MB              |
| Medium       | 2,000–10,000 items  | 150–500 MB            | 120–400 MB             |
| Large        | 10,000–30,000 items | 400 MB – 1.5 GB       | 300 MB – 1 GB          |
| Very Large   | 30,000+ items       | 1–3 GB+               | 800 MB - 2 GB+         |


Hourly backups are typically larger than daily backups because they include SQLite WAL files, while daily backups use the `.backup` method which produces a compacted database.

---

### Real-World Example

A Plex server with:
- ~1,600 movies  
- ~15,000 episodes  
- ~20 users  

Produces:

- Hourly snapshots: ~850 MB each  
- Daily backups: ~550 MB each  

---

### 📦 Storage Planning

Typical usage (Large Library):

* Hourly (24 snapshots):
  → ~20 GB

* Daily + Weekly + Monthly (GFS):
  → ~8–10 GB

**Total recommended storage: ~30 GB**

---

## ⚠️ Best Practices

### DO ✅

- **Keep hourly & GFS backups on separate disks** if possible
- **Monitor health check results** for early warning signs
- **Test restores regularly** (monthly recommended)
- **Adjust retention** based on your actual storage capacity
- **Automate everything** (no manual backups = missed backups)
- **Document your custom settings** (paths, retention, schedules)

### DON'T ❌

- **Rely on a single backup method** (defeats the purpose)
- **Ignore validation failures** (fix the root cause, don't disable checks)
- **Keep backups on the same disk as main database** (defeats redundancy)
- **Manually manage backup cleanup** (let the scripts handle it)
- **Use this as your only backup** (external drive backup recommended)

---

## 🚀 Recommended Setup

### Ideal Configuration

**Hourly Backups:**
- Frequency: Every hour (offset minute: :33)
- Destination: Fast SSD or NVMe
- Retention: 24 hours (automatic rotation)

**Daily GFS Backups:**
- Frequency: Once daily (3:10 AM)
- Destination: Different disk than hourly (slower HDD is fine)
- Retention: 7 days + 4 weeks + 6 months

**Health Checks:**
- Frequency: Once daily (6:00 AM, after GFS backup)
- Action: Notifications on failure

**External Backup:**
- Frequency: Weekly or monthly
- Destination: Network drive, cloud, or external USB
- Method: Manual or automated script (rsync, rclone, etc.)

---

## 📋 Quick Reference

| Layer | Speed | Downtime | Retention | Use Case |
|-------|-------|----------|-----------|----------|
| **Hourly** | ⚡ Fast (< 5 sec) | None | 24 hours | Recent recovery |
| **Daily GFS** | 🐢 Slower (15-45 sec) | < 5 sec | 6 months | Long-term rollback |
| **Health Check** | 🔍 Verify (3-5 min) | None | N/A | Reliability assurance |
| **Emergency** | 🛟 Last resort | N/A | N/A | Restore failure recovery |

---

## Summary

Your media files alone are not your Plex library... the database is the brain. The Plex Smart Backup Suite implements a **complete backup strategy**:

1. **Hourly snapshots** → Fast recovery for recent data loss
2. **GFS rotation** → Long-term protection with smart retention
3. **Validation layer** → Early warning system for backup failures
4. **Emergency backups** → Rollback if restore itself fails

Together, these provide fast recovery, long-term retention, and verified reliability for your Plex library.
