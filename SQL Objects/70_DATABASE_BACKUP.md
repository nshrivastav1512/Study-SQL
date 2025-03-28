# SQL Deep Dive: Database Backups

## 1. Introduction: Why Backups are Essential

Database backups are the cornerstone of any disaster recovery (DR) and business continuity plan. They are copies of your database data and transaction logs that allow you to **recover** your database to a specific point in time in case of hardware failure, data corruption, accidental deletion, or other disasters. Without regular, reliable backups, data loss can be catastrophic.

**Key Concepts:**

*   **Recovery Point Objective (RPO):** The maximum acceptable amount of data loss, measured in time (e.g., 15 minutes). Determines how frequently backups (especially log backups) need to occur.
*   **Recovery Time Objective (RTO):** The maximum acceptable downtime to recover the database after a failure. Influences the backup strategy and restore process complexity.
*   **Recovery Model:** A database property (`FULL`, `BULK_LOGGED`, `SIMPLE`) that controls transaction log management and determines which backup types are possible and what recovery options are available.

## 2. Backup Types and Strategies: Analysis of `70_DATABASE_BACKUP.sql`

This script demonstrates creating different backup types and discusses strategies.

**Part 1: Fundamentals**

*   Explains the purpose of backups and introduces the main types.

**Part 2: Creating Database Backups (`BACKUP DATABASE`, `BACKUP LOG`)**

*   **1. Full Backup:** A complete copy of the database at a point in time. Forms the base for restoration.
    ```sql
    -- Basic
    BACKUP DATABASE HRSystem TO DISK = 'C:\...\HRSystem_Full.bak' WITH NAME = '...', DESCRIPTION = '...';
    -- With Compression (Saves space, uses more CPU)
    BACKUP DATABASE HRSystem TO DISK = '...' WITH COMPRESSION, NAME = '...';
    -- With Checksum (Verifies page integrity during backup)
    BACKUP DATABASE HRSystem TO DISK = '...' WITH CHECKSUM, CONTINUE_AFTER_ERROR, NAME = '...';
    -- Copy-Only (Doesn't affect differential base or log chain - useful for ad-hoc backups)
    BACKUP DATABASE HRSystem TO DISK = '...' WITH COPY_ONLY, NAME = '...';
    ```
*   **2. Differential Backup:** Contains only the data extents changed *since the last full backup*. Faster to create than full backups, but requires the last full backup plus the latest differential for restore.
    ```sql
    -- Requires a prior Full backup
    BACKUP DATABASE HRSystem TO DISK = 'C:\...\HRSystem_Diff.bak' WITH DIFFERENTIAL, NAME = '...';
    ```
*   **3. Transaction Log Backup:** Backs up transaction log records generated since the last log backup (or full/differential if first log backup). Allows for point-in-time recovery. **Only possible in `FULL` or `BULK_LOGGED` recovery models.** Backing up the log also allows SQL Server to truncate the inactive portion of the log file, preventing uncontrolled growth.
    ```sql
    -- Requires FULL or BULK_LOGGED recovery model
    ALTER DATABASE HRSystem SET RECOVERY FULL;
    -- ... make changes ...
    BACKUP LOG HRSystem TO DISK = 'C:\...\HRSystem_Log.bak' WITH NAME = '...';
    -- With NORECOVERY (Used for Log Shipping - leaves DB in restoring state)
    -- BACKUP LOG HRSystem TO DISK = '...' WITH NORECOVERY, NAME = '...';
    ```

**Part 3: Backup Strategies for Different Recovery Models**

*   **1. `SIMPLE` Recovery Model:**
    *   **Characteristics:** Minimal logging. Log is automatically truncated at checkpoints. No transaction log backups possible. Point-in-time recovery is **not** possible. Risk of data loss since the last full/differential backup.
    *   **Strategy:** Regular Full backups (e.g., daily) + optional Differential backups more frequently.
    *   **Use Case:** Development, test, or non-critical databases where some data loss is acceptable.
*   **2. `FULL` Recovery Model:**
    *   **Characteristics:** All operations fully logged. Log truncation only occurs after a log backup. Allows point-in-time recovery. Highest protection against data loss.
    *   **Strategy:** Regular Full backups (e.g., weekly/daily) + regular Differential backups (e.g., daily/hourly) + frequent Transaction Log backups (e.g., every 5-60 minutes, depending on RPO).
    *   **Use Case:** Production OLTP databases, critical systems requiring minimal data loss (low RPO).
*   **3. `BULK_LOGGED` Recovery Model:**
    *   **Characteristics:** Hybrid model. Fully logs most operations but minimally logs certain bulk operations (`BULK INSERT`, `SELECT INTO`, index rebuilds) to reduce log growth during these operations. Allows point-in-time recovery *unless* restoring includes a log backup containing minimally logged operations (then only restore to end of that log backup).
    *   **Strategy:** Similar to `FULL`, but often used temporarily during large bulk loads, followed by switching back to `FULL` and taking a log backup. Requires careful management.
    *   **Use Case:** Temporarily reducing log impact during large data loads/maintenance while generally needing point-in-time recovery capability.

**Part 4: Advanced Backup Techniques**

*   **1. Backup to Multiple Files (Striping):** Writing the backup simultaneously to multiple disk files can significantly speed up the backup process, especially for large databases on systems with multiple I/O channels.
    ```sql
    BACKUP DATABASE HRSystem TO DISK = 'file1.bak', DISK = 'file2.bak', DISK = 'file3.bak' WITH ...;
    ```
*   **2. Backup Encryption:** (SQL Server 2014+) Encrypts the backup file itself, protecting data even if the backup media is lost or stolen. Requires a Certificate or Asymmetric Key in the `master` database.
    ```sql
    -- Requires Master Key & Certificate setup
    BACKUP DATABASE HRSystem TO DISK = '...' WITH ENCRYPTION (ALGORITHM = AES_256, SERVER CERTIFICATE = BackupCert), ...;
    ```
*   **3. Partial Backup:** Backs up only specified filegroups (usually PRIMARY plus selected read-write filegroups). Useful for very large databases (VLDBs) where backing up everything is impractical, but requires a more complex restore strategy. Read-only filegroups can often be backed up less frequently.
    ```sql
    BACKUP DATABASE HRSystem FILEGROUP = 'PRIMARY' TO DISK = '...' WITH ...;
    ```

**Part 5: Monitoring and Managing Backups**

*   **1. View Backup History (`msdb..backupset`, `msdb..backupmediafamily`):** Query system tables in the `msdb` database to see details of past backup operations (type, start/end times, size, location).
    ```sql
    SELECT bs.database_name, bs.backup_start_date, ..., CASE bs.type ... END AS BackupType, bmf.physical_device_name, ...
    FROM msdb.dbo.backupset bs JOIN msdb.dbo.backupmediafamily bmf ON ...
    WHERE bs.database_name = 'HRSystem' ORDER BY bs.backup_start_date DESC;
    ```
*   **2. Check Backup Integrity (`RESTORE VERIFYONLY`):** Verifies that the backup set is complete and readable, performing checksum validation if checksums were used during backup. Does *not* validate the internal data structure consistency.
    ```sql
    RESTORE VERIFYONLY FROM DISK = 'C:\...\HRSystem_Full.bak';
    ```
*   **3. Backup Cleanup:** Regularly delete old backup files according to retention policies. Often implemented via SQL Agent Jobs or maintenance plans using T-SQL (like `xp_delete_file`) or PowerShell scripts. The script shows querying `msdb` to identify old files.

**Part 6: Real-World Backup Scenarios**

*   Outlines typical strategies for High-Availability Production (Full+Diff+Log), Data Warehouses (often Simple or Bulk-Logged with Full/Diff), and Development/Test (Simple with Full/Diff).

## 3. Targeted Interview Questions (Based on `70_DATABASE_BACKUP.sql`)

**Question 1:** What are the three main types of SQL Server backups, and what does each contain?

**Solution 1:**
1.  **Full Backup:** Contains a complete copy of the database data files at the time of backup, plus enough transaction log to ensure consistency. It's the baseline for recovery.
2.  **Differential Backup:** Contains only the data extents (pages) that have changed *since the last full backup*. It's smaller and faster than a full backup.
3.  **Transaction Log Backup:** Contains all transaction log records generated *since the last transaction log backup* (or the first full/differential backup if no prior log backup exists). It allows for point-in-time recovery (in FULL/BULK_LOGGED models) and enables log file truncation.

**Question 2:** Why are Transaction Log backups essential when using the `FULL` recovery model, beyond just allowing point-in-time recovery?

**Solution 2:** Transaction Log backups are essential in the `FULL` recovery model because they are the **only** mechanism that allows SQL Server to truncate the inactive portion of the transaction log file. Without regular log backups, the transaction log will grow continuously, potentially filling up the disk and causing database operations to halt. Log backups effectively "clear out" the committed transactions from the active log, marking the space as reusable.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Which recovery model does *not* allow transaction log backups?
    *   **Answer:** `SIMPLE`.
2.  **[Easy]** What `BACKUP` option creates a backup that doesn't interfere with the differential backup chain?
    *   **Answer:** `COPY_ONLY`.
3.  **[Medium]** To restore a database using a full backup and the latest differential backup, do you also need any transaction log backups taken *between* the full and differential backups?
    *   **Answer:** No. A differential backup contains all changes since the last full backup. To restore to the point the differential was taken, you only need the last full backup and that specific differential backup. Log backups are needed to roll forward *past* the time of the differential backup.
4.  **[Medium]** What is the potential downside of using `WITH COMPRESSION` when creating backups?
    *   **Answer:** Backup compression significantly increases **CPU usage** on the server during the backup operation, as the data needs to be compressed on the fly. While it reduces backup size and potentially backup time (due to less I/O), the increased CPU load needs to be considered.
5.  **[Medium]** What does `RESTORE VERIFYONLY` actually check? Does it guarantee the data within the backup is logically consistent?
    *   **Answer:** `RESTORE VERIFYONLY` primarily checks that the backup set is complete, readable, and that the header information is consistent. If the backup was created `WITH CHECKSUM`, it also validates the checksums on the backup pages. It does **not** perform a full logical consistency check of the database structures or data within the backup file (that would require a full `RESTORE`).
6.  **[Medium]** Can you perform a `BACKUP LOG` immediately after switching a database from `SIMPLE` to `FULL` recovery model?
    *   **Answer:** No. After switching from `SIMPLE` to `FULL` (or `BULK_LOGGED`), you must first take at least one **Full Backup** to establish the starting point for the log backup chain before you can perform the first `BACKUP LOG`.
7.  **[Hard]** What is the difference between the `FULL` and `BULK_LOGGED` recovery models regarding point-in-time recovery?
    *   **Answer:** Both allow point-in-time recovery by restoring log backups. However, under `BULK_LOGGED`, certain operations (like `BULK INSERT`, `SELECT INTO`, index rebuilds) are minimally logged. If a transaction log backup contains any minimally logged operations, you can only restore that specific log backup to its *end time*; you cannot perform a point-in-time restore *within* the time frame covered by that log backup. `FULL` recovery logs all operations fully, always allowing point-in-time recovery to any point contained within the log backups.
8.  **[Hard]** What is required to restore an encrypted backup created `WITH ENCRYPTION (..., SERVER CERTIFICATE = BackupCert)`?
    *   **Answer:** The certificate (`BackupCert`) used for encryption (including its private key) must exist and be available (and accessible) in the `master` database on the server instance where the `RESTORE` command is being executed. If restoring to a different server, the certificate and its private key must be backed up from the original server and restored to the `master` database of the destination server first.
9.  **[Hard]** Can you back up the `tempdb` database? Why or why not?
    *   **Answer:** No, you cannot back up the `tempdb` database. `tempdb` is recreated from scratch every time the SQL Server service starts. It only contains temporary objects and internal structures (like row versions for snapshot isolation) that are not needed for recovery. Backup and restore operations are not permitted or necessary for `tempdb`.
10. **[Hard/Tricky]** You take a full backup, then several log backups. Then, you take a differential backup, followed by more log backups. To restore to a point in time *after* the differential backup was taken, which backups do you absolutely need?
    *   **Answer:** You absolutely need:
        1.  The last **Full Backup** (taken before the differential).
        2.  The last **Differential Backup** (taken after the full backup).
        3.  **All Transaction Log Backups** taken *after* the differential backup, up to and including the log backup containing the desired point in time.
    *   You do *not* need the log backups taken *between* the full and the differential backup, as the differential contains all changes since the full.
