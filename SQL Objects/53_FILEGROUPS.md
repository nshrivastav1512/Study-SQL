# SQL Deep Dive: Filegroups

## 1. Introduction: What are Filegroups?

In SQL Server, a **Filegroup** is a logical container that groups one or more physical data files (`.mdf`, `.ndf`). Databases are created with at least one filegroup, the **PRIMARY** filegroup, which contains the primary data file (`.mdf`) and any other files not explicitly assigned elsewhere. You can create additional **user-defined filegroups** to organize data storage.

**Why use Filegroups?**

*   **Storage Management & Performance:** Place different tables, indexes, or partitions onto different filegroups, which can then be mapped to different physical disks or storage tiers (e.g., place heavily accessed tables/indexes on fast SSDs, archive data on slower HDDs). This allows for better I/O balancing and performance optimization.
*   **Partitioning:** Filegroups are essential for table partitioning, as each partition defined by a partition scheme must be mapped to a filegroup. This allows different data ranges (e.g., different years) to reside on different physical storage.
*   **Administration & Backup/Restore:** Allow for piecemeal backup and restore operations. You can back up or restore individual filegroups (though this adds complexity compared to full database backups). Read-only filegroups can simplify backup strategies.
*   **Data Allocation:** Control where new data or indexes are physically placed by specifying the target filegroup during object creation or by setting the default filegroup for the database.

**Key Concepts:**

*   **PRIMARY Filegroup:** Every database has one. Contains the primary data file (`.mdf`) and system tables. If no other filegroup is specified as default, new objects are created here.
*   **User-Defined Filegroup:** Additional filegroups created by the user (`ADD FILEGROUP`).
*   **Data File (`.mdf`, `.ndf`):** The physical operating system files that store the database data and objects. Each data file belongs to exactly one filegroup.
*   **Default Filegroup:** The filegroup where new objects are created if no filegroup is specified explicitly. Can be changed from PRIMARY using `ALTER DATABASE ... MODIFY FILEGROUP ... DEFAULT`.
*   **Read-Only Filegroup:** A filegroup marked as read-only prevents data modification within the files belonging to it. Useful for archiving or static data.

**Key Commands:**

*   `CREATE DATABASE ... FILEGROUP ... (...)`
*   `ALTER DATABASE ... ADD FILEGROUP ...`
*   `ALTER DATABASE ... ADD FILE (...) TO FILEGROUP ...`
*   `ALTER DATABASE ... MODIFY FILEGROUP ... [DEFAULT | READ_ONLY | READ_WRITE]`
*   `ALTER DATABASE ... REMOVE FILE ...`
*   `ALTER DATABASE ... REMOVE FILEGROUP ...`
*   `CREATE TABLE ... ON FilegroupName`
*   `CREATE INDEX ... ON FilegroupName`
*   `ALTER TABLE ... ADD CONSTRAINT ... ON FilegroupName` (For PK/Unique to move table)

## 2. Filegroups in Action: Analysis of `53_FILEGROUPS.sql`

This script demonstrates creating and managing filegroups and files. *Note: Requires administrative permissions and valid file paths.*

**a) Creating Database with Multiple Filegroups**

```sql
CREATE DATABASE FileGroupDemo
ON PRIMARY (... NAME = 'FGDemo_Primary', FILENAME = 'C:\...\FGDemo_Primary.mdf' ...),
FILEGROUP FG_Data (... NAME = 'FGDemo_Data', FILENAME = 'C:\...\FGDemo_Data.ndf' ...)
LOG ON (...);
```

*   **Explanation:** Creates a new database with the standard `PRIMARY` filegroup and an additional user-defined filegroup named `FG_Data`. Each filegroup has at least one data file associated with it, specifying its logical name, physical path, initial size, max size, and growth increment.

**b) Adding Filegroup to Existing Database (`ADD FILEGROUP`)**

```sql
ALTER DATABASE FileGroupDemo ADD FILEGROUP FG_Archive;
```

*   **Explanation:** Adds a new, empty filegroup named `FG_Archive` to the existing `FileGroupDemo` database.

**c) Adding File to Filegroup (`ADD FILE ... TO FILEGROUP`)**

```sql
ALTER DATABASE FileGroupDemo ADD FILE (...) TO FILEGROUP FG_Archive;
```

*   **Explanation:** Adds a new physical data file (`.ndf`) and associates it with the specified filegroup (`FG_Archive`). A filegroup can contain multiple files, allowing data within that filegroup to be spread across them (often on different physical disks).

**d) Setting Default Filegroup (`MODIFY FILEGROUP ... DEFAULT`)**

```sql
ALTER DATABASE FileGroupDemo MODIFY FILEGROUP FG_Data DEFAULT;
```

*   **Explanation:** Changes the default filegroup for the database from `PRIMARY` to `FG_Data`. New tables or indexes created without an explicit `ON FilegroupName` clause will now be placed in `FG_Data`.

**e) Creating Read-Only Filegroup (`MODIFY FILEGROUP ... READ_ONLY`)**

```sql
ALTER DATABASE FileGroupDemo ADD FILEGROUP FG_ReadOnly;
ALTER DATABASE FileGroupDemo ADD FILE (...) TO FILEGROUP FG_ReadOnly;
ALTER DATABASE FileGroupDemo MODIFY FILEGROUP FG_ReadOnly READ_ONLY;
-- To make writable again: ALTER DATABASE FileGroupDemo MODIFY FILEGROUP FG_ReadOnly READ_WRITE;
```

*   **Explanation:** Creates a filegroup and then marks it as read-only. No data modifications can occur on objects stored within this filegroup. Useful for historical or archive data that should not be changed.

**f) Creating Tables on Specific Filegroups (`ON FilegroupName`)**

```sql
CREATE TABLE dbo.CurrentEmployees (...) ON FG_Data; -- Explicitly place on FG_Data
CREATE TABLE dbo.ArchivedEmployees (...) ON FG_Archive; -- Place on FG_Archive
```

*   **Explanation:** Uses the `ON FilegroupName` clause in `CREATE TABLE` to specify which filegroup the table's data (specifically, its clustered index or heap) should be stored in.

**g) Creating Indexes on Specific Filegroups**

```sql
CREATE TABLE dbo.Products (...) ON FG_Data; -- Table data on FG_Data
CREATE NONCLUSTERED INDEX IX_Products_Category ON dbo.Products(...) ON FG_Archive; -- Index on FG_Archive
```

*   **Explanation:** Demonstrates placing a table's data (clustered index/heap) on one filegroup (`FG_Data`) and a non-clustered index for that table on a *different* filegroup (`FG_Archive`). This allows separating table data I/O from index I/O onto different physical disks if desired.

**h) Partitioning with Filegroups**

```sql
CREATE PARTITION FUNCTION PF_EmployeesByYear(...);
CREATE PARTITION SCHEME PS_EmployeesByYear AS PARTITION PF_EmployeesByYear TO (FG_Archive, FG_Archive, FG_Data, FG_Data, PRIMARY);
CREATE TABLE dbo.EmployeeHistory (...) ON PS_EmployeesByYear(ActionDate);
```

*   **Explanation:** Shows a key use case. The partition scheme maps different logical partitions (defined by the function `PF_EmployeesByYear`) to specific filegroups. Here, older data (partitions 1 & 2) goes to `FG_Archive`, recent data (partitions 3 & 4) goes to `FG_Data`, and future data (partition 5) goes to `PRIMARY`.

**i) Moving Objects Between Filegroups**

```sql
-- Drop existing PK (which dictates location for clustered tables)
ALTER TABLE dbo.CurrentEmployees DROP CONSTRAINT PK_...;
-- Recreate PK ON the desired filegroup
ALTER TABLE dbo.CurrentEmployees ADD CONSTRAINT PK_CurrentEmployees PRIMARY KEY (EmployeeID) ON FG_Data;
```

*   **Explanation:** Moving an existing table between filegroups typically involves rebuilding its clustered index (often the primary key) `ON` the target filegroup. For heaps (tables without a clustered index), you would need to create a clustered index `ON` the target filegroup and potentially drop it again if a heap is desired. Non-clustered indexes can be moved using `CREATE INDEX ... WITH (DROP_EXISTING = ON) ON TargetFilegroup`.

**j) Querying Filegroup Information (System Views)**

```sql
-- List filegroups
SELECT fg.name, fg.type_desc, fg.is_read_only, fg.is_default FROM sys.filegroups fg;
-- List files and their filegroups
SELECT f.name, f.physical_name, fg.name AS FileGroupName, ... FROM sys.database_files f LEFT JOIN sys.filegroups fg ON ...;
-- Find object locations
SELECT ..., fg.name AS FileGroupName FROM sys.tables t JOIN sys.indexes i ON ... JOIN sys.filegroups fg ON i.data_space_id = fg.data_space_id;
```

*   **Explanation:** Uses system views `sys.filegroups` and `sys.database_files` to get information about defined filegroups and their associated physical files. Joins with `sys.indexes` can show where tables and indexes are physically stored.

**k) Filegroup Maintenance (Space Usage)**

```sql
SELECT fg.name, SUM(f.size)/128 AS TotalSizeMB, SUM(FILEPROPERTY(f.name, 'SpaceUsed'))/128 AS UsedSpaceMB, ...
FROM sys.filegroups fg JOIN sys.database_files f ON ... GROUP BY fg.name;
```

*   **Explanation:** Queries system views and functions (`FILEPROPERTY`) to report on the total allocated, used, and free space within each filegroup.

**l/m) Removing Files and Filegroups**

```sql
-- Empty the file first
DBCC SHRINKFILE (FileName, EMPTYFILE);
-- Remove the file definition
ALTER DATABASE FileGroupDemo REMOVE FILE FileName;
-- Remove the (now empty) filegroup
ALTER DATABASE FileGroupDemo REMOVE FILEGROUP FilegroupName;
```

*   **Explanation:** To remove a filegroup, it must first be empty (contain no data files). To remove a data file, it must first be emptied using `DBCC SHRINKFILE ... EMPTYFILE`, which moves its data to other files *within the same filegroup*. The `PRIMARY` filegroup and its files cannot be removed.

**n) Filegroup Best Practices (Example)**

*   **Explanation:** Suggests creating filegroups based on data access patterns (e.g., `FG_HotData` for frequently accessed tables, potentially on faster storage).

**o) Filegroup Backup and Restore**

```sql
BACKUP DATABASE FileGroupDemo FILEGROUP = 'FG_Data' TO DISK = '...';
-- RESTORE DATABASE FileGroupDemo FILEGROUP = 'FG_Data' FROM DISK = '...' WITH PARTIAL, NORECOVERY;
-- RESTORE LOG ...
```

*   **Explanation:** Demonstrates backing up only specific filegroups. Restoring requires backing up the PRIMARY filegroup and all transaction logs since the filegroup backup. Piecemeal restore adds complexity and is usually only used in specific scenarios for very large databases (VLDBs).

## 3. Targeted Interview Questions (Based on `53_FILEGROUPS.sql`)

**Question 1:** What is the relationship between a database, filegroups, and data files (`.mdf`/`.ndf`)?

**Solution 1:** A database contains one or more **filegroups**. The `PRIMARY` filegroup is mandatory. Each filegroup contains one or more physical **data files** (`.mdf` for primary, `.ndf` for secondary). Database objects like tables and indexes are created `ON` a specific filegroup (or the default one), meaning their data is physically stored within the data file(s) belonging to that filegroup.

**Question 2:** Why might you place a table's non-clustered indexes on a different filegroup than the table's data (clustered index or heap)?

**Solution 2:** Placing non-clustered indexes on separate filegroups (ideally mapped to different physical disks) allows for parallel I/O operations. When querying the table, SQL Server might read data from the base table (e.g., via the clustered index on Filegroup A) and simultaneously read data from a non-clustered index (on Filegroup B). If Filegroup A and Filegroup B are on separate physical disks, this can significantly improve I/O throughput and query performance compared to having both the table and index data competing for I/O on the same disk(s).

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** What is the name of the mandatory filegroup present in every SQL Server database?
    *   **Answer:** `PRIMARY`.
2.  **[Easy]** Can a single data file (`.mdf` or `.ndf`) belong to multiple filegroups?
    *   **Answer:** No. Each data file belongs to exactly one filegroup.
3.  **[Medium]** How do you change which filegroup is used by default when creating new tables or indexes without specifying an `ON` clause?
    *   **Answer:** Use the `ALTER DATABASE ... MODIFY FILEGROUP FilegroupName DEFAULT;` command.
4.  **[Medium]** Can you drop the `PRIMARY` filegroup? Can you remove the primary data file (`.mdf`)?
    *   **Answer:** No to both. The `PRIMARY` filegroup and the primary data file are essential components of the database and cannot be removed.
5.  **[Medium]** What must be true about a filegroup before you can drop it using `ALTER DATABASE ... REMOVE FILEGROUP`?
    *   **Answer:** The filegroup must be empty; it cannot contain any data files. You must first empty and remove all files associated with the filegroup.
6.  **[Medium]** If a table is created `ON FG_Data`, where will its non-clustered indexes be created by default if no `ON` clause is specified in the `CREATE INDEX` statement?
    *   **Answer:** By default, non-clustered indexes are created on the **same filegroup as the base table** (or clustered index), which would be `FG_Data` in this case.
7.  **[Hard]** How can filegroups be used in conjunction with table partitioning to manage large tables?
    *   **Answer:** A partition scheme maps the logical partitions (defined by a partition function based on a column's value range) to physical filegroups. This allows different ranges of data (e.g., different years or quarters) to be stored on separate filegroups, which can then be placed on different physical storage tiers (fast vs. slow) or managed independently (e.g., making older filegroups read-only, backing up specific filegroups).
8.  **[Hard]** What is the purpose of the `EMPTYFILE` option in `DBCC SHRINKFILE`? When is it typically used?
    *   **Answer:** `DBCC SHRINKFILE (FileName, EMPTYFILE)` attempts to move all data extents from the specified `FileName` to *other files within the same filegroup*. Its purpose is to empty the specified file so that it can subsequently be removed from the database using `ALTER DATABASE ... REMOVE FILE FileName`. It's a prerequisite step before removing a data file from a filegroup that contains multiple files.
9.  **[Hard]** Can you place the transaction log (`.ldf` file) in a user-defined filegroup?
    *   **Answer:** No. Transaction log files are managed separately from data files and filegroups. They are specified in the `LOG ON` clause of `CREATE DATABASE` or added using `ALTER DATABASE ... ADD LOG FILE`. They do not belong to data filegroups.
10. **[Hard/Tricky]** If you create a table `ON FG1` and later want to move it entirely to `FG2`, what is generally the most efficient way to do this for a table with a clustered primary key, assuming minimal downtime is desired (Enterprise Edition)?
    *   **Answer:** The most efficient way is typically to recreate the clustered index (which is often the primary key) on the target filegroup using the `DROP_EXISTING = ON` and `ONLINE = ON` options:
        ```sql
        CREATE UNIQUE CLUSTERED INDEX PK_MyTable -- Use same name as existing PK
        ON dbo.MyTable (PKColumn(s))
        WITH (DROP_EXISTING = ON, ONLINE = ON)
        ON FG2; -- Specify the target filegroup
        ```
        `DROP_EXISTING = ON` makes the drop and create atomic. `ONLINE = ON` allows concurrent DML during the move/rebuild (though it takes longer and uses more resources). This effectively moves the table data to the new filegroup by rebuilding its clustered structure there.
