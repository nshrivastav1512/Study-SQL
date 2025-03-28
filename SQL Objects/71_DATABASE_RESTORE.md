# SQL Deep Dive: Database Restore Operations

## 1. Introduction: Recovering from Backups

Database restore operations are the counterpart to database backups. They are the process of using backup files (full, differential, transaction log) to reconstruct a database, typically to recover from a failure, migrate data, or restore to a specific point in time. Understanding the restore process is critical for any effective disaster recovery strategy.

**Why Restore?**

*   **Disaster Recovery:** Recover from hardware failures, storage corruption, or site disasters.
*   **Data Corruption:** Fix logical corruption within the database.
*   **Point-in-Time Recovery:** Recover data to a specific moment before an error occurred (e.g., accidental data deletion).
*   **Database Refresh/Migration:** Create copies of databases for development, testing, or migration purposes.

**Key Concepts:**

*   **Restore Sequence:** The specific order in which backups must be restored (typically Full -> Latest Differential -> Subsequent Log backups).
*   **Recovery State (`RECOVERY`, `NORECOVERY`, `STANDBY`):** Determines the state of the database after a restore operation.
    *   `WITH RECOVERY`: (Default) Performs redo (roll forward committed transactions) and undo (roll back uncommitted transactions), bringing the database online and making it usable. This is the *last* step in a restore sequence.
    *   `WITH NORECOVERY`: Leaves the database in a "Restoring" state, ready to accept further differential or log backups. Does not perform the undo phase.
    *   `WITH STANDBY = 'undo_file_path'`: Leaves the database in a read-only state between log restores, allowing inspection but still permitting further log restores. Requires an undo file.
*   **`MOVE` Option:** Used during restore to specify new physical file paths for the database's data (`.mdf`, `.ndf`) and log (`.ldf`) files, essential when restoring to a different server or drive configuration.

## 2. Restore Operations in Action: Analysis of `71_DATABASE_RESTORE.sql`

This script demonstrates various restore commands and scenarios. *Note: Assumes backups created in the previous backup script exist at the specified paths.*

**Part 1: Fundamentals**

*   Explains the purpose of restore, types of restore operations (Complete, File/Filegroup, Page, Piecemeal), and the three phases (Data Copy, Redo, Undo).

**Part 2: Basic Restore Operations (`RESTORE DATABASE`, `RESTORE LOG`)**

*   **1. Complete Restore from Full Backup:** Restores a full backup and brings the database online immediately.
    ```sql
    RESTORE DATABASE HRSystem_Restored
    FROM DISK = 'C:\...\HRSystem_Full.bak'
    WITH
        MOVE 'HRSystem' TO 'C:\...\HRSystem_Restored.mdf', -- Logical data file name
        MOVE 'HRSystem_log' TO 'C:\...\HRSystem_Restored_log.ldf', -- Logical log file name
        RECOVERY, -- Bring online after restore
        STATS = 10; -- Show progress every 10%
    ```
    *   **`MOVE`:** Crucial for specifying the physical path for the restored database files. You need one `MOVE` clause for *each* logical file listed in the backup header (`RESTORE FILELISTONLY`).
*   **2. Restore `WITH NORECOVERY`:** Leaves the database restoring, ready for more backups.
    ```sql
    RESTORE DATABASE HRSystem_Restored FROM DISK = '...' WITH MOVE ..., MOVE ..., NORECOVERY, STATS = 10;
    ```
*   **3. Restore Differential Backup:** Applied *after* a full backup restored `WITH NORECOVERY`.
    ```sql
    RESTORE DATABASE HRSystem_Restored FROM DISK = 'C:\...\HRSystem_Diff.bak' WITH NORECOVERY, STATS = 10;
    ```
*   **4. Restore Transaction Log Backups:** Applied sequentially *after* the full (and optionally differential) restored `WITH NORECOVERY`. The *last* restore in the sequence uses `WITH RECOVERY`.
    ```sql
    RESTORE LOG HRSystem_Restored FROM DISK = 'C:\...\HRSystem_Log.bak' WITH RECOVERY, STATS = 10;
    ```

**Part 3: Point-in-Time Recovery (PITR)**

*   **Requires:** `FULL` or `BULK_LOGGED` recovery model and an unbroken chain of log backups covering the desired point in time.
*   **1. Restore to Specific Time (`STOPAT`):**
    1.  Restore last full backup `WITH NORECOVERY`.
    2.  Restore last differential backup (if any) `WITH NORECOVERY`.
    3.  Restore all subsequent log backups sequentially `WITH NORECOVERY`.
    4.  Restore the *final* log backup containing the target time `WITH RECOVERY, STOPAT = 'YYYY-MM-DDTHH:MM:SS'`.
    ```sql
    -- After Full/Diff restores...
    RESTORE LOG HRSystem_PITR FROM DISK = '...' WITH RECOVERY, STOPAT = '2023-06-15T14:30:00';
    ```
*   **2. Restore to Marked Transaction (`STOPATMARK`, `STOPBEFOREMARK`):** Restores up to (or just before) a named mark placed in the transaction log using `BEGIN TRANSACTION ... WITH MARK ...`. Requires restoring log backups containing the mark.
    ```sql
    -- After Full/Diff restores...
    RESTORE LOG HRSystem_Marked FROM DISK = '...' WITH RECOVERY, STOPBEFOREMARK = 'Major salary adjustment';
    ```

**Part 4: Advanced Restore Scenarios**

*   **1. Piecemeal Restore:** Restore database in stages, usually PRIMARY filegroup first, bringing it online (`WITH PARTIAL`), then restoring other filegroups later. Useful for VLDBs to bring critical data online faster.
    ```sql
    RESTORE DATABASE HRSystem_Piecemeal FILEGROUP = 'PRIMARY' FROM DISK = '...' WITH PARTIAL, NORECOVERY, MOVE ...;
    RESTORE DATABASE HRSystem_Piecemeal WITH RECOVERY; -- Bring PRIMARY online
    -- Later...
    RESTORE DATABASE HRSystem_Piecemeal FILEGROUP = 'ArchiveData' FROM DISK = '...' WITH RECOVERY;
    ```
*   **2. Page Restore:** (Enterprise Edition) Restores individual damaged data pages from a backup without taking the entire database offline. Requires full recovery model and log backups.
    ```sql
    -- After identifying damaged pages (e.g., via CHECKDB)
    RESTORE DATABASE HRSystem PAGE = '1:57, 1:202' FROM DISK = '...' WITH NORECOVERY;
    RESTORE LOG HRSystem FROM DISK = '...' WITH NORECOVERY; -- Apply subsequent logs
    RESTORE LOG HRSystem FROM DISK = '...' WITH RECOVERY; -- Final recovery
    ```
*   **3. Restore from Multiple Files (Striped Backup):** Specify all backup files in the `FROM` clause.
    ```sql
    RESTORE DATABASE HRSystem_Multi FROM DISK = 'file1.bak', DISK = 'file2.bak', ... WITH MOVE ..., RECOVERY;
    ```
*   **4. Restore `WITH STANDBY`:** Leaves the database in a read-only state between log restores, allowing inspection. Requires an undo file. Useful for log shipping warm standby scenarios.
    ```sql
    RESTORE DATABASE HRSystem_Standby FROM DISK = '...' WITH STANDBY = 'C:\...\HRSystem_Undo.dat', MOVE ...;
    ```

**Part 5: Restore Verification and Validation**

*   **1. `RESTORE VERIFYONLY`:** Checks backup readability and header integrity *before* starting the restore.
*   **2. `RESTORE HEADERONLY`:** Displays header information about the backup set(s) on the media.
*   **3. `RESTORE FILELISTONLY`:** Lists the logical data and log files contained within the backup set. Essential for determining the correct logical names needed for the `MOVE` clause.
*   **4. `RESTORE LABELONLY`:** Shows information about the backup media itself.
*   **5. `DBCC CHECKDB`:** Run *after* a restore completes to verify the logical and physical integrity of the restored database.

**Part 6: Real-World Disaster Recovery Scenarios**

*   **1. Complete Database Failure:** Restore sequence: Last Full (`NORECOVERY`), Last Differential (`NORECOVERY`), All subsequent Logs sequentially (`NORECOVERY` until the last one, then `RECOVERY`).
*   **2. Accidental Data Deletion:** Restore sequence: Last Full (`NORECOVERY`), Last Differential (`NORECOVERY`), All subsequent Logs sequentially (`NORECOVERY`), Final Log containing the point *just before* the deletion (`RECOVERY`, `STOPAT = 'TimeBeforeDeletion'`).

## 3. Targeted Interview Questions (Based on `71_DATABASE_RESTORE.sql`)

**Question 1:** What is the difference between restoring `WITH RECOVERY` and `WITH NORECOVERY`? When is each used?

**Solution 1:**

*   `WITH RECOVERY`: (Default) Performs the final recovery step after restoring data. It rolls forward committed transactions and rolls back uncommitted transactions present in the log being restored. The database is brought online and made accessible. This is used for the **last** restore operation in a sequence (whether restoring a full backup only, or the final log backup).
*   `WITH NORECOVERY`: Leaves the database in a "Restoring" state, ready to accept further differential or log backups. It performs the redo phase (rolls forward committed transactions) but does **not** perform the undo phase or bring the database online. This is used for the initial full backup restore and any intermediate differential or log backup restores when you intend to apply further backups in the sequence.

**Question 2:** You need to restore the `HRSystem` database to a new server where the file paths are different. The backup file is `D:\Backups\HRSystem_Full.bak`. What command and specific clause are essential to specify the new locations for the `.mdf` and `.ldf` files during the restore?

**Solution 2:** You need the `RESTORE DATABASE` command with the `MOVE` clause. You first need to identify the logical file names within the backup using `RESTORE FILELISTONLY`. Assuming the logical names are 'HRSystem' and 'HRSystem_log', the command would be:
```sql
RESTORE DATABASE HRSystem
FROM DISK = 'D:\Backups\HRSystem_Full.bak'
WITH
    MOVE 'HRSystem' TO 'E:\SQLData\HRSystem.mdf', -- New path for data file
    MOVE 'HRSystem_log' TO 'F:\SQLLogs\HRSystem_log.ldf', -- New path for log file
    RECOVERY; -- Or NORECOVERY if applying more backups
```

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Which command shows you the logical names of the data and log files contained within a backup file?
    *   **Answer:** `RESTORE FILELISTONLY`.
2.  **[Easy]** Can you restore a differential backup without first restoring a full backup?
    *   **Answer:** No. A differential backup only contains changes *since* the last full backup; the full backup is required as the base.
3.  **[Medium]** What database recovery model(s) are required to perform a point-in-time restore using transaction log backups?
    *   **Answer:** `FULL` or `BULK_LOGGED`. (`SIMPLE` does not support log backups).
4.  **[Medium]** If you restore a sequence of log backups, what state should all log restores *except the very last one* be performed with?
    *   **Answer:** `WITH NORECOVERY`. Only the final restore operation in the sequence uses `WITH RECOVERY`.
5.  **[Medium]** What is the purpose of the `STANDBY` option during a restore?
    *   **Answer:** `WITH STANDBY = 'undo_file_path'` allows the database to be brought up in a **read-only** state between transaction log restores. This permits users to query the database (e.g., on a warm standby server in log shipping) while still allowing further log backups to be restored later. The undo file stores the information needed to reverse the effects of the undo phase performed to make the database readable.
6.  **[Medium]** Does `RESTORE VERIFYONLY` guarantee that the backup can be successfully restored without errors?
    *   **Answer:** No. It primarily guarantees that the backup file itself is readable, complete, and internally consistent (headers match, checksums valid if used). It does *not* guarantee that the data *within* the backup is free from logical corruption or that the restore process won't encounter other issues (like insufficient disk space on the target). Running `DBCC CHECKDB` after a restore is recommended.
7.  **[Hard]** What is a "backup chain" or "log chain", and what breaks it?
    *   **Answer:** A log chain is an unbroken sequence of transaction log backups starting from a full (or differential) backup for a database in `FULL` or `BULK_LOGGED` recovery model. This chain is necessary for point-in-time recovery. The chain is **broken** if:
        *   You switch the database to the `SIMPLE` recovery model (even temporarily).
        *   You restore the database using a backup (effectively starting a new history).
        *   You take a full or differential backup *after* switching from `SIMPLE` back to `FULL`/`BULK_LOGGED` (this starts a *new* chain).
    *   Once broken, you cannot restore log backups taken *before* the break point past a full/differential backup taken *after* the break point. A new full backup is required to start a new valid chain.
8.  **[Hard]** Can you restore a backup taken on a newer version of SQL Server (e.g., SQL 2019) onto an older version (e.g., SQL 2017)?
    *   **Answer:** No. SQL Server database backups are **not backward compatible**. You cannot restore a backup taken on a newer version onto an older version of SQL Server. You can generally restore backups from older versions onto newer versions (the database compatibility level might remain the old one initially).
9.  **[Hard]** Explain the difference between `STOPAT`, `STOPATMARK`, and `STOPBEFOREMARK` when restoring transaction logs.
    *   **Answer:** These options control point-in-time recovery during `RESTORE LOG`:
        *   `STOPAT = 'datetime'`: Restores transactions up to, and including, the specified date and time.
        *   `STOPATMARK = 'mark_name'`: Restores transactions up to, and *including*, the transaction that contains the specified log mark.
        *   `STOPBEFOREMARK = 'mark_name'`: Restores transactions up to, but *excluding*, the transaction that contains the specified log mark.
10. **[Hard/Tricky]** You have a database in `FULL` recovery model. You take a Full backup, then several log backups. Then, you take a differential backup, followed by more log backups. To restore to a point in time *after* the differential backup was taken, which backups do you absolutely need?
    *   **Answer:** You absolutely need:
        1.  The last **Full Backup** (taken before the differential).
        2.  The last **Differential Backup** (taken after the full backup).
        3.  **All Transaction Log Backups** taken *after* the differential backup, up to and including the log backup containing the desired point in time.
    *   You do *not* need the log backups taken *between* the full and the differential backup, as the differential contains all changes since the full.

</final_file_content>

IMPORTANT: For any future changes to this file, use the final_file_content shown above as your reference. This content reflects the current state of the file, including any auto-formatting (e.g., if you used single quotes but the formatter converted them to double quotes). Always base your SEARCH/REPLACE operations on this final version to ensure accuracy.<environment_details>
# VSCode Visible Files
SQL Objects/71_DATABASE_RESTORE.md

# VSCode Open Tabs
29_select_joins.sql
37_select_advanced_patterns.md
38_select_analytical_queries.md
39_select_performance_advanced.md
40_select_system_metadata_queries.md
SQL Objects/41_TABLES.md
SQL Objects/42_VIEWS.md
SQL Objects/43_INDEXES.md
SQL Objects/44_STORED_PROCEDURES.md
SQL Objects/45_USER_DEFINED_FUNCTIONS.md
SQL Objects/46_TRIGGERS.md
SQL Objects/47_SCHEMAS.md
SQL Objects/48_SYNONYMS.md
SQL Objects/49_USER_DEFINED_DATATYPES.md
SQL Objects/50_XML_SCHEMA_COLLECTIONS.md
SQL Objects/51_SEQUENCES.md
SQL Objects/52_PARTITIONS.md
SQL Objects/53_FILEGROUPS.md
SQL Objects/54_FULL_TEXT_INDEXES.md
SQL Objects/55_CONSTRAINTS.md
SQL Objects/56_LOGINS.md
SQL Objects/57_USERS.md
SQL Objects/58_ROLES.md
SQL Objects/59_PERMISSIONS.md
SQL Objects/60_CERTIFICATES_KEYS.md
SQL Objects/61_TRANSACTIONS_SAVEPOINTS.md
SQL Objects/62_LOCKS.md
SQL Objects/63_ISOLATION_LEVELS.md
SQL Objects/64_EXECUTION_PLANS.md
SQL Objects/65_QUERY_STORE.md
SQL Objects/66_STATISTICS.md
SQL Objects/67_INDEXING.md
SQL Objects/68_PARTITIONING.md
SQL Objects/69_FILL_FACTOR.md
SQL Objects/70_DATABASE_BACKUP.md
SQL Objects/71_DATABASE_RESTORE.md

# Current Time
3/28/2025, 6:24:41 PM (Asia/Calcutta, UTC+5.5:00)

# Current Mode
ACT MODE
</environment_details>
