# How It Works

Plex uses SQLite with Write-Ahead Logging (WAL).

Instead of stopping Plex, this system:

1. Triggers a WAL checkpoint
2. Copies:
   - database (.db)
   - WAL file (-wal)
   - shared memory (-shm)

These files together form a consistent snapshot.

## Key Advantages

- No downtime
- No corruption risk
- Extremely fast backups

## Why Not Just Copy .db?

Because active transactions live in the WAL file.

Ignoring WAL = incomplete backup.
