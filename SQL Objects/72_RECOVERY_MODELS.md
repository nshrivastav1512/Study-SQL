# SQL Deep Dive: Database Recovery Models

## 1. Introduction: What are Recovery Models?

A **Recovery Model** is a database property in SQL Server that dictates how transactions are logged, whether the transaction log requires backing up, and consequently, what recovery options (like point-in-time restore) are available for that database. Choosing the correct recovery model is a fundamental decision in your backup and recovery strategy, balancing data protection needs (Recovery Point Objective - RPO) against administrative overhead and performance impact.

**SQL Server offers three recovery models:**

1.  **`FULL`:** Provides the highest level of data protection. All operations are fully logged. Requires transaction log backups. Allows recovery to any specific point in time.
2.  **`SIMPLE`:** Provides the simplest log management. Log space is automatically reused (truncated) after checkpoints. Does *not* support transaction log backups. Recovery is limited to the time of the last full or differential backup. Highest risk of data loss between backups.
3.  **`BULK_LOGGED`:** A supplement to the `FULL` model. Fully logs most operations but minimally logs certain bulk operations (like `BULK INSERT`, `SELECT INTO`, index rebuilds) to improve performance and reduce log growth during these specific operations. Requires log backups but limits point-in-time recovery capability *during* the minimally logged operations.

## 2. Recovery Models in Action: Analysis of `72_RECOVERY_MODELS.sql`

This script explains and demonstrates each recovery model.

**Part 1: Fundamentals**

*   Defines recovery models and their purpose (controlling logging, backups, restore options).
*   Lists the three models: `FULL`, `SIMPLE`, `BULK_LOGGED`.
*   Shows how to view the current recovery model for databases:
    ```sql
    SELECT name, recovery_model_desc FROM sys.databases;
    ```

**Part 2: `FULL` Recovery Model**

*   **Characteristics:**
    *   All operations fully logged.
    *   Supports point-in-time recovery (PITR).
    *   **Requires** regular transaction log backups to prevent log file growth and allow log truncation.
    *   Highest data protection, lowest risk of data loss.
*   **Logging:** Every `INSERT`, `UPDATE`, `DELETE`, DDL operation is fully recorded in the transaction log.
*   **Backup Strategy:** Requires a chain of Full backups + optional Differential backups + **mandatory frequent Transaction Log backups**.
*   **Recovery:** Can restore to any point in time contained within the log backups.
*   **Use Case:** Critical production databases (OLTP systems) where data loss must be minimized (low RPO).

**Part 3: `SIMPLE` Recovery Model**

*   **Characteristics:**
    *   Minimal logging (only enough to ensure transaction rollback).
    *   Log space is automatically reclaimed (truncated) after checkpoints; log file generally stays small.
    *   Transaction log backups are **not supported** and not needed.
    *   Point-in-time recovery is **not possible**.
    *   Recovery only possible to the time of the last Full or Differential backup.
*   **Logging:** Transactions are logged, but once a transaction commits and a checkpoint occurs, the log space becomes reusable.
*   **Backup Strategy:** Requires regular Full backups + optional Differential backups.
*   **Recovery:** Can only restore the last Full or the last Full + last Differential backup. All work done since the last backup is lost upon restore.
*   **Use Case:** Development databases, test databases, read-only databases, or any scenario where point-in-time recovery is not required and data loss between backups is acceptable.

**Part 4: `BULK_LOGGED` Recovery Model**

*   **Characteristics:**
    *   Hybrid approach. Most operations are fully logged like `FULL`.
    *   Certain bulk operations (`BULK INSERT`, `SELECT INTO`, `CREATE INDEX`, `ALTER INDEX REBUILD`, `WRITETEXT`, `UPDATETEXT`) are **minimally logged** (only extent allocations and metadata changes are logged, not individual rows).
    *   Requires transaction log backups, similar to `FULL`.
    *   Reduces log space usage and improves performance *during* bulk operations compared to `FULL`.
*   **Logging:** Minimal logging for supported bulk operations; full logging for everything else.
*   **Backup Strategy:** Requires Full + optional Differential + mandatory Log backups.
*   **Recovery:** Allows point-in-time recovery, **except** if restoring a log backup that contains minimally logged operations. In that case, you can only restore the *entire* log backup (recovering to the end time of that log), not to a specific point *within* it.
*   **Use Case:** Typically used temporarily during large bulk data loads or index maintenance on a database that normally runs in `FULL` recovery, to speed up the operation and reduce log growth, before switching back to `FULL`.

**Part 5: Switching Between Recovery Models (`ALTER DATABASE ... SET RECOVERY ...`)**

*   **Switching from `SIMPLE` to `FULL` (or `BULK_LOGGED`):**
    ```sql
    ALTER DATABASE MyDatabase SET RECOVERY FULL;
    -- CRITICAL: Take an immediate Full Backup!
    BACKUP DATABASE MyDatabase TO DISK = '...';
    ```
    *   **Explanation:** Breaks the previous log truncation behavior. A **Full Backup is required immediately** after switching to start the log backup chain needed for `FULL` or `BULK_LOGGED` recovery.
*   **Switching from `FULL` (or `BULK_LOGGED`) to `SIMPLE`:**
    ```sql
    ALTER DATABASE MyDatabase SET RECOVERY SIMPLE;
    ```
    *   **Explanation:** Breaks the log backup chain. SQL Server will start automatically truncating the log at checkpoints. Point-in-time recovery capability is lost from this point forward.
*   **Switching between `FULL` and `BULK_LOGGED`:**
    ```sql
    ALTER DATABASE MyDatabase SET RECOVERY BULK_LOGGED;
    -- Perform Bulk Operations...
    ALTER DATABASE MyDatabase SET RECOVERY FULL;
    -- Recommended: Take a Log Backup soon after switching back to FULL
    BACKUP LOG MyDatabase TO DISK = '...';
    ```
    *   **Explanation:** Switching between `FULL` and `BULK_LOGGED` does *not* break the log chain. However, taking a log backup after switching back to `FULL` ensures that any minimally logged operations are captured in the backup sequence and full point-in-time recovery capability is maintained going forward.

**Part 6: Best Practices**

*   **`FULL`:** Use for production databases requiring point-in-time recovery and minimal data loss. Requires diligent log backup scheduling and monitoring.
*   **`SIMPLE`:** Use for non-production databases (Dev, Test), read-only databases, or where data loss between full/differential backups is acceptable. Simplest administration.
*   **`BULK_LOGGED`:** Use *temporarily* during planned bulk operations on databases normally in `FULL` recovery to improve performance and reduce log impact. Switch back to `FULL` and take a log backup afterward. Avoid using it as a permanent setting unless the limitations on PITR are fully understood and acceptable.

## 3. Targeted Interview Questions (Based on `72_RECOVERY_MODELS.sql`)

**Question 1:** What is the key difference between the `SIMPLE` and `FULL` recovery models regarding transaction log backups and point-in-time recovery?

**Solution 1:**
*   **`SIMPLE`:** Does **not** support transaction log backups. Log space is automatically reused. Point-in-time recovery is **not** possible; recovery is limited to the last full or differential backup.
*   **`FULL`:** **Requires** transaction log backups to manage log space and enable recovery. All transactions are fully logged. Supports point-in-time recovery to any moment covered by the log backups.

**Question 2:** You need to perform a large data load using `BULK INSERT` into a production database that is currently in `FULL` recovery model. You want to minimize the impact on the transaction log during the load but still need point-in-time recovery capability generally. What steps involving recovery models would you typically take?

**Solution 2:**
1.  **Switch to `BULK_LOGGED`:** Before starting the bulk operation, switch the database recovery model: `ALTER DATABASE YourDB SET RECOVERY BULK_LOGGED;`
2.  **Perform Bulk Operation:** Execute the `BULK INSERT` (or other minimally logged operation like index rebuild).
3.  **Switch back to `FULL`:** After the bulk operation completes successfully: `ALTER DATABASE YourDB SET RECOVERY FULL;`
4.  **Take Log Backup:** Immediately take a transaction log backup (`BACKUP LOG YourDB TO DISK = '...';`). This ensures the minimally logged operations are captured in the backup chain and maintains the ability for future point-in-time recovery.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** What is the default recovery model for new user databases in SQL Server?
    *   **Answer:** It depends on the recovery model of the `model` database at the time the user database is created. By default, `model` is usually `FULL`, so new databases typically default to `FULL`.
2.  **[Easy]** Can you perform differential backups in the `SIMPLE` recovery model?
    *   **Answer:** Yes. Differential backups are based on changes since the last *full* backup and are supported in all recovery models.
3.  **[Medium]** What happens to the transaction log file size if you are using the `FULL` recovery model but never take transaction log backups?
    *   **Answer:** The transaction log file (`.ldf`) will grow continuously and will never be truncated (internally marked as reusable). Eventually, it can fill up the available disk space, causing database operations to fail.
4.  **[Medium]** Does switching from `FULL` to `SIMPLE` recovery model immediately shrink the transaction log file?
    *   **Answer:** No. Switching to `SIMPLE` allows the log to *start* being truncated automatically at subsequent checkpoints, but it doesn't immediately shrink the physical file size. You would need to issue a separate `DBCC SHRINKFILE` command on the log file after switching (and potentially after a checkpoint) to reduce its physical size, though shrinking log files frequently is often discouraged.
5.  **[Medium]** If a database is in `BULK_LOGGED` recovery model, are *all* operations minimally logged?
    *   **Answer:** No. Only specific bulk operations (like `BULK INSERT`, `SELECT INTO`, index rebuilds under certain conditions) are minimally logged. Standard DML operations (`INSERT`, `UPDATE`, `DELETE`) are still fully logged, just as in the `FULL` recovery model.
6.  **[Medium]** What action is required immediately after switching a database from `SIMPLE` to `FULL` recovery model to enable point-in-time recovery?
    *   **Answer:** You must take a **Full Database Backup**. This establishes the starting point for the transaction log backup chain.
7.  **[Hard]** Can you restore a database to a specific point in time if you only have Full and Differential backups (no Log backups)?
    *   **Answer:** No. Point-in-time recovery requires transaction log backups. With only Full and Differential backups, you can only restore to the point in time when the Full backup finished or when the Differential backup finished.
8.  **[Hard]** If you perform a minimally logged operation under the `BULK_LOGGED` recovery model and then take a transaction log backup, what information about the bulk operation is actually stored in that log backup?
    *   **Answer:** The log backup will contain the log records describing the *extent allocations* and metadata changes related to the bulk operation, rather than the detailed log records for each individual row affected. This allows SQL Server to redo the *entire* bulk operation during restore but prevents restoring to a point *within* that bulk operation.
9.  **[Hard]** Does changing the recovery model require taking the database offline?
    *   **Answer:** No. Changing the recovery model using `ALTER DATABASE ... SET RECOVERY ...` is an online operation and does not require taking the database offline.
10. **[Hard/Tricky]** You have a database in `FULL` recovery. You take a Full backup. You then switch to `BULK_LOGGED`, perform an index rebuild (minimally logged), switch back to `FULL`, and then take a Log backup. Can you perform a point-in-time restore to a time *during* the index rebuild?
    *   **Answer:** No. Because the log backup taken *after* switching back to `FULL` contains the results of the minimally logged index rebuild operation, you cannot restore to a point *within* the time frame covered by that specific log backup. You could restore *up to the beginning* of that log backup (using prior backups), or restore the *entire* log backup (recovering past the index rebuild), but not to a point during the rebuild itself.
