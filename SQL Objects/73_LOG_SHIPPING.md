# SQL Deep Dive: Log Shipping

## 1. Introduction: What is Log Shipping?

Log Shipping is a native SQL Server solution primarily used for **Disaster Recovery (DR)**, providing a **warm standby** database. It works by automatically backing up transaction logs from a primary (production) database, copying these backup files across the network to one or more secondary servers, and restoring them onto secondary databases.

**Key Concepts:**

*   **Primary Server/Database:** The production server and database whose transaction logs are being backed up.
*   **Secondary Server/Database:** The standby server(s) where log backups are restored. The secondary database is typically kept in a `NORECOVERY` or `STANDBY` state.
*   **Monitor Server (Optional):** A separate server instance used to track the status, history, and alerts for the log shipping configuration. Recommended for easier management.
*   **Backup Job:** Runs on the primary server, performs `BACKUP LOG`.
*   **Copy Job:** Runs on the secondary server(s), copies backup files from the primary's share to a local folder on the secondary.
*   **Restore Job:** Runs on the secondary server(s), restores the copied log backups to the secondary database.
*   **Recovery State:**
    *   `NORECOVERY`: Secondary database is in a restoring state, not accessible. Allows continuous log restores.
    *   `STANDBY`: Secondary database is in a read-only state between restores. Allows querying the secondary for reporting but requires disconnecting users during each restore job.

**Why use Log Shipping?**

*   **Disaster Recovery:** Provides an up-to-date copy of the database on a separate server for failover if the primary fails.
*   **Read-Only Reporting (Standby Mode):** Offload read-only queries to the secondary server (with some latency and potential disruption during restores).
*   **Simplicity:** Relatively straightforward to configure compared to more complex HA/DR solutions like Always On Availability Groups.
*   **Cost-Effective:** Doesn't typically require Enterprise Edition features (unlike Always On AGs or Database Mirroring with automatic failover).

## 2. Log Shipping in Action: Analysis of `73_LOG_SHIPPING.sql`

This script outlines the concepts, prerequisites, setup steps (conceptual T-SQL), monitoring, and failover procedures.

**Part 1: Fundamentals**

*   Explains the concept, components (Primary, Secondary, Monitor), the process (Backup, Copy, Restore), and compares it briefly to other HA/DR options.

**Part 2: Prerequisites**

*   **Primary Database:** Must be in `FULL` or `BULK_LOGGED` recovery model. An initial full backup is needed to initialize the secondary.
*   **Secondary Server:** Accessible instance with sufficient disk space.
*   **Shared Folder:** Network share accessible by SQL Server service accounts on both primary (write) and secondary (read) servers for storing backup files.
*   **Permissions:** SQL Server Agent service accounts need appropriate permissions on the shared folder and potentially across servers (if using Windows Authentication for SQL Server services).

**Part 3: Setting Up Log Shipping**

*   **Using SSMS:** The script notes the wizard-based approach in SSMS (Database Properties > Transaction Log Shipping) which simplifies configuration by creating the necessary jobs and using system stored procedures.
*   **Using T-SQL (Conceptual):** Provides commented-out examples of the core system stored procedures involved:
    1.  **On Primary:** `sp_add_log_shipping_primary_database` (Configures primary DB, backup job settings, retention, monitoring).
    2.  **On Secondary:** `RESTORE DATABASE ... WITH NORECOVERY` (Initial restore from full backup).
    3.  **On Secondary:** `sp_add_log_shipping_secondary_primary` (Registers primary info on secondary, configures copy job).
    4.  **On Secondary:** `sp_add_log_shipping_secondary_database` (Configures secondary DB, restore job settings, restore mode - `NORECOVERY` or `STANDBY`, restore delay).
    *   *Note: Executing these manually requires careful parameterization and understanding.*

**Part 4: Monitoring Log Shipping**

*   **Using SSMS:** The Log Shipping Monitor node provides a graphical overview of status and history.
*   **Using T-SQL (System Tables in `msdb`):**
    *   `msdb.dbo.log_shipping_primary_databases`: Status on the primary (last backup, etc.).
    *   `msdb.dbo.log_shipping_secondary_databases`: Status on the secondary (last copy, last restore, etc.).
    *   `msdb.dbo.log_shipping_monitor_error_detail`: History of errors from backup, copy, restore jobs.

**Part 5: Failover and Recovery Procedures**

*   **1. Planned Failover (Manual):**
    1.  Ensure all logs are copied/restored to secondary.
    2.  Take a final "tail-log" backup of the primary `WITH NORECOVERY` (puts primary in restoring state).
    3.  Copy this final log backup to the secondary.
    4.  Restore the final log backup on the secondary `WITH RECOVERY` (brings secondary online as new primary).
    5.  Redirect clients to the new primary server.
*   **2. Unplanned Failover (Manual):**
    1.  If the primary server fails unexpectedly.
    2.  Attempt a final tail-log backup if possible (`WITH NO_TRUNCATE`). If successful, copy and restore it `WITH RECOVERY`.
    3.  If tail-log backup fails, restore existing copied logs `WITH NORECOVERY`.
    4.  Finally, bring the secondary online using `RESTORE DATABASE SecondaryDB WITH RECOVERY;`. **Note:** Any transactions in the un-backed-up tail of the primary's log will be lost (potential data loss up to the RPO).
    5.  Redirect clients to the new primary server.
*   **3. Failback:** After the original primary is repaired, reverse the log shipping configuration (new primary becomes LS primary, old primary becomes LS secondary), synchronize, and perform a planned failover back.

**Part 6: Advanced Configurations**

*   **Multiple Secondaries:** Possible for increased redundancy or different reporting needs.
*   **Delayed Restore:** Configure `sp_add_log_shipping_secondary_database` with `@restore_delay` > 0. The restore job waits the specified number of minutes before restoring copied log files. Provides a buffer against logical errors propagating immediately to the secondary.
*   **Read-Only Access (`STANDBY` Mode):** Configure secondary with `@restore_mode = 1`. The restore job brings the database into read-only mode between restores, using an undo file (`.tuf`). Users querying the secondary will be disconnected during each restore job execution.
*   **Custom Schedules:** Modify the SQL Agent job schedules created by log shipping setup (`msdb.dbo.sp_update_schedule`) to match specific RPO/RTO requirements.

**Part 7: Troubleshooting**

*   **Common Issues:** Backup failures (disk space, permissions), Copy failures (network, share permissions, service accounts), Restore failures (disk space, database state, sequence errors).
*   **Monitoring:** Use `msdb` log shipping tables, SQL Agent job history, and SQL Server error logs to diagnose failures.

## 3. Targeted Interview Questions (Based on `73_LOG_SHIPPING.sql`)

**Question 1:** What is the primary purpose of Log Shipping in SQL Server?

**Solution 1:** The primary purpose of Log Shipping is **Disaster Recovery (DR)**. It provides a warm standby copy of a production database on a separate server by automatically backing up, copying, and restoring transaction logs, allowing for manual failover in case the primary server becomes unavailable. It can also be used for read-only reporting offloading if the secondary is configured in `STANDBY` mode.

**Question 2:** What database recovery models support Log Shipping, and why?

**Solution 2:** Log Shipping requires the primary database to be in either the **`FULL`** or **`BULK_LOGGED`** recovery model. This is because Log Shipping relies on the ability to take **transaction log backups**, which are only possible under these two recovery models. The `SIMPLE` recovery model automatically truncates the log and does not support log backups, making it incompatible with Log Shipping.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Does Log Shipping provide automatic failover?
    *   **Answer:** No. Failover in Log Shipping is a **manual** process.
2.  **[Easy]** What are the three main jobs created by a typical Log Shipping configuration?
    *   **Answer:** Backup job (on primary), Copy job (on secondary), Restore job (on secondary).
3.  **[Medium]** What is the difference between restoring a secondary database `WITH NORECOVERY` versus `WITH STANDBY` in a Log Shipping setup?
    *   **Answer:**
        *   `NORECOVERY`: Leaves the database in a "Restoring" state, inaccessible to users. Allows subsequent log backups to be restored without interruption.
        *   `STANDBY`: Brings the database online in a **read-only** state between log restores, allowing users to query it. Requires an undo file (`.tuf`) and disconnects users during each restore operation.
4.  **[Medium]** Can you have multiple secondary servers in a Log Shipping configuration?
    *   **Answer:** Yes. A single primary database can ship logs to multiple secondary servers.
5.  **[Medium]** What happens to the transaction log on the primary database after a successful log backup job runs in a Log Shipping configuration (assuming `FULL` recovery model)?
    *   **Answer:** After a successful log backup, the inactive portion of the primary database's transaction log (containing log records for committed transactions that are no longer needed for recovery or replication) can be marked as reusable and potentially truncated (internally) by subsequent checkpoints, helping to manage log file size.
6.  **[Medium]** What is the purpose of the optional Monitor Server in Log Shipping?
    *   **Answer:** The Monitor Server acts as a central point for tracking the status, history, and alerts for all primary and secondary databases involved in the log shipping configuration. It simplifies monitoring by consolidating information and raising alerts if backups, copies, or restores fall behind schedule or fail.
7.  **[Hard]** If the primary database fails and you perform an unplanned failover to the secondary, what determines the potential amount of data loss?
    *   **Answer:** The potential data loss is determined by the transactions that occurred on the primary database *since the last successful transaction log backup* that was copied and restored to the secondary server. If a final "tail-log" backup could not be taken from the failed primary, any transactions in that tail portion of the log are lost. The frequency of log backups and the copy/restore job schedules directly influence the Recovery Point Objective (RPO).
8.  **[Hard]** Can you use Log Shipping if the primary and secondary servers have different versions or editions of SQL Server?
    *   **Answer:** Generally, the secondary server must be the **same version or a newer version** of SQL Server than the primary. You cannot ship logs from a newer version to an older version. Regarding editions, Log Shipping itself works across different editions (e.g., Standard primary to Standard secondary, or Standard primary to Enterprise secondary), as long as the versions are compatible.
9.  **[Hard]** What is the `@restore_delay` setting used for when configuring the secondary database in Log Shipping?
    *   **Answer:** The `@restore_delay` parameter (in `sp_add_log_shipping_secondary_database`) specifies a time delay (in minutes) between when a log backup file is copied to the secondary and when the restore job actually restores it. This provides a buffer, allowing you time to react if a logical error (like an accidental mass delete) occurs on the primary; you could potentially stop the restore job on the secondary before the bad transaction is applied there.
10. **[Hard/Tricky]** If the Copy job fails repeatedly due to network issues, but the Backup job on the primary continues successfully, what happens to the transaction log file on the primary server (assuming `FULL` recovery model)?
    *   **Answer:** The transaction log file on the primary server will **continue to grow**. Even though the Backup job is succeeding, the log space cannot be reused (truncated) until those log backup files have been successfully processed (copied and potentially restored) by the secondary according to the log shipping configuration's tracking. The failure of the Copy job breaks the chain from the perspective of log space reuse on the primary, leading to log file growth.
