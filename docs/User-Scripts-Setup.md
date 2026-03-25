# 🛠️ Unraid User Scripts Setup Guide

This guide will help you automate the **Plex Smart Backup Suite** using the **User Scripts** plugin in Unraid.

## 1️⃣ Install the Plugin
If you haven't already, install the **User Scripts** plugin from the **Apps** (Community Applications) tab in Unraid.

## 2️⃣ Add the Scripts
For each script in the `/scripts` folder of this repo (e.g., `Plex_Hourly_Backup.sh`, `Plex_Daily_Backups.sh`, `Plex-Hourly-Healthcheck.sh`):

1. Go to **Settings** -> **User Scripts**.
2. Click **Add New Script** and give it a name (e.g., `Plex_Hourly_Backup`).
3. Click the **Gear Icon** next to the new script and select **Edit Script**.
4. Paste the contents of the `.sh` file from this repo into the window.
5. **Important:** Edit the `USER CONFIGURATION` section at the top of the script to match your server's paths.
6. Click **Save Changes**.

## 3️⃣ Recommended Schedule
To get the most out of the suite's "layered" protection, set the following schedules:

| Script | Schedule | Frequency |
| :--- | :--- | :--- |
| `Plex_Hourly_Backup.sh` | **Custom:** `33 * * * *` | Once per hour (at minute 33) |
| `Plex_Daily_Backups.sh` | **Custom** `10 3 * * *` | Once per day (this is at 3:10 AM) |
| `Plex-Hourly-Healthcheck.sh` | **Custom:** `45 3 * * *` | Once per day at (this is at 3:45 AM) |

> [!TIP]
> Setting the Hourly backup to an "off-set" minute like `33` ensures it doesn't collide with other system tasks that usually start exactly on the hour.

## 4️⃣ Validation & Testing
After setting up the schedules:
1. Click **Run Script** manually for the `Plex_Hourly_Backup`.
2. Review the Log that appears after **Run Script** or select **View Log** to ensure it created the snapshot without errors.
3. Check your backup destination folder in the Unraid **File Manager** or via SMB to confirm the files are there.

## ⚠️ Safety Note
When performing a **Restore**:
1. The **Restore** scripts will automatically **Stop the Plex Container** after they locate a good backup and before they restore. They will restart the **Plex** container after the restore is complete.
2. Always keep the `DRY_RUN=true` flag enabled for your first test run to ensure paths are mapped correctly.
