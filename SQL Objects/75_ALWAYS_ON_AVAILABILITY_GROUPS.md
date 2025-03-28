# SQL Deep Dive: Always On Availability Groups (AGs)

## 1. Introduction: What are Availability Groups?

**Always On Availability Groups (AGs)** is SQL Server's premier **High Availability (HA)** and **Disaster Recovery (DR)** solution (primarily Enterprise Edition, with Basic AGs in Standard Edition having limitations). It provides failover capabilities for a defined set of user databases, known as **availability databases**, that fail over together as a single unit.

Unlike older technologies like Database Mirroring or Log Shipping which operate on a single database, AGs operate on a group of databases. They leverage Windows Server Failover Clustering (WSFC) for infrastructure and health monitoring but do *not* require shared storage like Failover Cluster Instances (FCIs). Each server participating in an AG hosts a copy of the databases and is called an **Availability Replica**.

**Key Concepts:**

*   **Availability Group (AG):** A container for one or more user databases (Availability Databases) that fail over together.
*   **Availability Replica:** An instance of SQL Server hosting a copy of the availability databases. Resides on a node in the underlying WSFC cluster.
*   **Primary Replica:** Hosts the read-write copy of the databases. All changes originate here. Only one primary replica exists at any time.
*   **Secondary Replica:** Hosts read-only or non-accessible copies of the databases. Receives transaction log records from the primary. Can have multiple secondary replicas (up to 8 total replicas in modern versions).
*   **Availability Mode:**
    *   **Synchronous-Commit Mode:** Transactions are committed on the primary *and* at least one synchronous secondary before being acknowledged to the client. Enables automatic failover with zero data loss. Requires low network latency.
    *   **Asynchronous-Commit Mode:** Transactions are committed on the primary without waiting for acknowledgment from the secondary replica. Offers better performance over high-latency links but involves potential data loss during failover. Only supports manual failover.
*   **Failover Mode:**
    *   **Automatic:** (Requires Synchronous-Commit mode) If the primary replica becomes unavailable, WSFC and SQL Server automatically transition a synchronous secondary replica to the primary role without data loss.
    *   **Manual:** An administrator initiates the failover (planned or forced).
*   **Availability Group Listener:** A virtual network name (VNN) and IP address that client applications connect to. The listener directs connections to the current primary replica (for read-write) or potentially to a read-only secondary (if read-only routing is configured). Provides seamless client redirection after failover.
*   **WSFC (Windows Server Failover Clustering):** Provides the underlying infrastructure for node health monitoring, quorum, and coordinating automatic failover.

**Benefits:**

*   High Availability (HA) with automatic failover (synchronous mode).
*   Disaster Recovery (DR) using asynchronous replicas in remote data centers.
*   Increased data protection (zero data loss possible with synchronous mode).
*   Read Scale-Out by offloading read-only workloads to readable secondary replicas.
*   Backup Offloading by performing backups on secondary replicas.
*   Failover of multiple databases as a single unit.

## 2. Availability Groups in Action: Analysis of `75_ALWAYS_ON_AVAILABILITY_GROUPS.sql`

This script outlines the concepts, prerequisites, setup steps (conceptual T-SQL), monitoring, and failover procedures. *Note: Actual AG setup is complex and usually involves SSMS wizards or detailed PowerShell/T-SQL scripting, including WSFC configuration.*

**Part 1: Fundamentals**

*   Defines AGs, key components (AG, Replicas, Listener), benefits, and prerequisites (WSFC, Enterprise Edition often needed, Full Recovery Model).

**Part 2: Preparing for AGs**

*   **1. WSFC Configuration:** Emphasizes the need to set up the underlying Windows cluster first (install feature, validate, create cluster). This is done at the OS level.
*   **2. SQL Server Configuration:** Shows enabling the AG feature on each SQL Server instance via `sp_configure 'hadr enabled', 1;` (requires restart).
*   **3. Sample Database:** Creates a database (`HRSystem_AG`), sets it to `FULL` recovery model, and takes an initial **Full Backup**. A full backup (and potentially log backups) are required to initialize secondary replicas.

**Part 3: Creating an Availability Group (Conceptual T-SQL)**

*   **Using SSMS:** Mentions the wizard as a common approach.
*   **Using T-SQL:** Provides conceptual examples:
    *   `CREATE AVAILABILITY GROUP`: Defines the AG name, options (like `AUTOMATED_BACKUP_PREFERENCE`), lists databases, and defines the replicas.
    *   `REPLICA ON 'ServerName' WITH (...)`: Specifies each replica's settings:
        *   `ENDPOINT_URL`: The Database Mirroring Endpoint URL for communication.
        *   `AVAILABILITY_MODE`: `SYNCHRONOUS_COMMIT` or `ASYNCHRONOUS_COMMIT`.
        *   `FAILOVER_MODE`: `AUTOMATIC` or `MANUAL`.
        *   `BACKUP_PRIORITY`: Preference for where backups should run.
        *   `SECONDARY_ROLE(ALLOW_CONNECTIONS = ...)`: Configures secondary replica access (`NO`, `READ_ONLY`, `ALL`).
    *   `CREATE ENDPOINT`: Defines the communication endpoint on each instance.
    *   `GRANT CONNECT ON ENDPOINT`: Grants permission for service accounts to connect.
    *   `ALTER AVAILABILITY GROUP ... JOIN`: Command run on secondary replicas to join the AG.
    *   `RESTORE DATABASE ... WITH NORECOVERY`: Restore backups on secondaries to prepare them.
    *   `ALTER DATABASE ... SET HADR AVAILABILITY GROUP = ...`: Joins the restored database on the secondary to the AG.
    *   `ALTER AVAILABILITY GROUP ... ADD LISTENER`: Creates the virtual network name and IP address for client connections.

**Part 4: Monitoring Availability Groups (DMVs)**

*   **Using SSMS:** Mentions the AG Dashboard.
*   **Using T-SQL (DMVs):** Shows querying key DMVs:
    *   `sys.availability_groups`: Information about the AG itself.
    *   `sys.availability_replicas`: Information about each replica's configuration.
    *   `sys.dm_hadr_database_replica_states`: Runtime status of databases on each replica (synchronization state, health, LSNs).
    *   `sys.availability_group_listeners`: Information about the listener configuration.

**Part 5: Failover Procedures**

*   **1. Planned Manual Failover:** (`ALTER AVAILABILITY GROUP ... FAILOVER;`) Performed on the current primary replica for scheduled maintenance. Requires synchronous-commit mode and a synchronized secondary. No data loss.
*   **2. Forced Manual Failover (`... FORCE_FAILOVER_ALLOW_DATA_LOSS;`):** Performed on a secondary replica when the primary is unavailable (disaster scenario). **Carries risk of data loss** if the secondary was not fully synchronized (e.g., asynchronous mode, or synchronous mode with unsent logs). Use as a last resort.
*   **3. Automatic Failover:** Occurs automatically between synchronous-commit replicas with `FAILOVER_MODE = AUTOMATIC` when WSFC detects a primary failure and quorum is maintained.

**Part 6: Advanced Configurations**

*   **1. Read-Only Routing:** Configures the listener and replicas to direct read-intent connection strings (`ApplicationIntent=ReadOnly`) to specific readable secondary replicas, enabling read scale-out. Requires defining a `READ_ONLY_ROUTING_LIST` for each replica.
*   **2. Distributed Availability Groups:** (SQL 2016+) An AG whose members are other AGs residing in different WSFC clusters (can be cross-domain or cross-platform). Used primarily for DR across geographically separate locations or complex topologies. Uses `CREATE AVAILABILITY GROUP ... WITH (DISTRIBUTED)` and `ALTER AVAILABILITY GROUP ... JOIN AVAILABILITY GROUP ...`.

## 3. Targeted Interview Questions (Based on `75_ALWAYS_ON_AVAILABILITY_GROUPS.sql`)

**Question 1:** What is the difference between Synchronous-Commit Mode and Asynchronous-Commit Mode in an Availability Group? What is the trade-off?

**Solution 1:**

*   **Synchronous-Commit Mode:** The primary replica waits to commit a transaction until it receives acknowledgment that the transaction log records have been hardened (written to disk) on at least one synchronous secondary replica.
    *   **Benefit:** Enables automatic failover and guarantees zero data loss (RPO=0) for failovers between synchronous replicas.
    *   **Trade-off:** Introduces transaction latency because the primary must wait for the secondary's acknowledgment. Requires low-latency network connection between synchronous replicas.
*   **Asynchronous-Commit Mode:** The primary replica commits transactions without waiting for acknowledgment from the secondary replica. Log records are sent asynchronously.
    *   **Benefit:** Minimizes transaction latency on the primary, suitable for replicas over high-latency networks (e.g., DR sites).
    *   **Trade-off:** Only supports manual failover, and there is potential for data loss (RPO>0) because the secondary might lag behind the primary.

**Question 2:** What is the purpose of the Availability Group Listener? How does it help client applications?

**Solution 2:** The Availability Group Listener provides a single, virtual connection point (a Virtual Network Name and IP address) for client applications to connect to the Availability Group. It abstracts the physical replica instances. The listener automatically directs incoming connections to the current primary replica (for read-write workloads). If read-only routing is configured, it can also direct read-intent connections to designated readable secondary replicas. This helps client applications by providing seamless redirection after a failover – applications always connect to the listener name, and the listener ensures they reach the appropriate active replica without needing connection string changes.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** What underlying Windows feature is required for Always On Availability Groups?
    *   **Answer:** Windows Server Failover Clustering (WSFC).
2.  **[Easy]** Can you include system databases (like `master`, `msdb`) in an Availability Group?
    *   **Answer:** No. Availability Groups only support user databases. System databases require other methods for HA/DR (e.g., backups, FCIs).
3.  **[Medium]** What database recovery model is required for databases participating in an Availability Group?
    *   **Answer:** `FULL` recovery model.
4.  **[Medium]** What is the difference between an Availability Group and a Failover Cluster Instance (FCI)?
    *   **Answer:**
        *   **AG:** Provides database-level protection (a set of databases fail over). Uses independent storage for each replica. Requires WSFC. Can have readable secondaries.
        *   **FCI:** Provides instance-level protection. The entire SQL Server instance fails over between nodes. Requires shared storage accessible by all nodes in the FCI. Requires WSFC. Secondaries are not active or readable.
5.  **[Medium]** Can you perform backups (Full, Diff, Log) on a secondary replica? What is the `AUTOMATED_BACKUP_PREFERENCE` setting for?
    *   **Answer:** Yes, you can perform `COPY_ONLY` Full backups and regular Log backups on secondary replicas (Differential backups are not supported on secondaries). The `AUTOMATED_BACKUP_PREFERENCE` setting (`PRIMARY`, `SECONDARY_ONLY`, `SECONDARY`, `NONE`) helps backup tools or scripts determine which replica is preferred for taking backups, often used to offload backup workload from the primary.
6.  **[Medium]** What happens to client connections directed to the listener during an automatic failover?
    *   **Answer:** Existing connections to the old primary are typically terminated. New connection attempts directed to the listener will be automatically routed to the newly promoted primary replica once the failover is complete and the listener comes online associated with the new primary. Applications may need retry logic in their connection strings/code to handle the brief interruption.
7.  **[Hard]** What is "seeding mode" (`AUTOMATIC` vs `MANUAL`) when adding a replica or database to an AG?
    *   **Answer:** Seeding mode determines how the secondary database is initially created and synchronized.
        *   `MANUAL` (Traditional): Requires the DBA to manually back up the database and logs on the primary, copy the files, and restore them `WITH NORECOVERY` on the secondary before joining the database to the AG.
        *   `AUTOMATIC` (SQL 2016+): Uses **Direct Seeding**. SQL Server automatically creates the database on the secondary and streams the data directly over the network from the primary to seed the secondary replica. Simplifies setup but requires appropriate network bandwidth and permissions.
8.  **[Hard]** Can a secondary replica be in Synchronous-Commit mode but have `FAILOVER_MODE = MANUAL`? If so, why might you configure this?
    *   **Answer:** Yes. This configuration ensures zero data loss (RPO=0) because commits wait for log hardening on the secondary, but it prevents SQL Server/WSFC from *automatically* failing over to that secondary if the primary fails. You might use this if you want zero data loss protection but require an administrator to manually verify the situation and initiate the failover, perhaps due to application dependencies or specific operational procedures.
9.  **[Hard]** What is required for Read-Only Routing to function correctly?
    *   **Answer:**
        1.  The secondary replica(s) intended for read traffic must be configured for read access (`ALLOW_CONNECTIONS = READ_ONLY` or `ALL`).
        2.  A **Read-Only Routing URL** must be configured for each readable secondary replica (`READ_ONLY_ROUTING_URL` option in `ALTER AVAILABILITY GROUP ... MODIFY REPLICA`).
        3.  A **Read-Only Routing List** must be defined on the primary replica (and potentially other secondaries that could become primary) specifying the order in which to direct read-intent connections (`PRIMARY_ROLE(READ_ONLY_ROUTING_LIST = (...))`).
        4.  Client connection strings must specify `ApplicationIntent=ReadOnly` and connect to the **Availability Group Listener**.
10. **[Hard/Tricky]** Can you have databases with different collations within the same Availability Group? What about system objects like logins or SQL Agent jobs?
    *   **Answer:**
        *   **Database Collations:** Yes, databases with different collations can coexist within the same AG. The AG replicates the databases as they are.
        *   **System Objects:** No. Logins, SQL Agent jobs, linked servers, credentials, etc., are instance-level objects stored in `master` or `msdb`. They are **not** automatically replicated or synchronized by the Availability Group. You must manually create and synchronize these objects on all replicas where they are needed to ensure consistency and proper functioning after a failover. This is a critical administrative task when managing AGs.
