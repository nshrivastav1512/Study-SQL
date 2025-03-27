# SQL Deep Dive: Table Partitioning

## 1. Introduction: What is Table Partitioning?

Table Partitioning is a feature in SQL Server (primarily Enterprise Edition, though some basic functionality exists in Standard) that allows you to divide large tables (or indexes) into smaller, more manageable chunks called **partitions**. The data is horizontally divided based on the value of a specific **partitioning column** (e.g., a date column, a region ID). While logically the table still appears as a single entity, physically the data is stored across these separate partitions.

**Why use Partitioning?**

*   **Manageability:** Operations like loading new data, archiving old data, or performing index maintenance can often be done much more efficiently on individual partitions rather than the entire large table. This is especially true for time-based data where you might load new months/years or archive old ones.
*   **Performance (Partition Elimination):** If queries frequently filter data based on the partitioning column (e.g., `WHERE OrderDate >= '2023-01-01' AND OrderDate < '2024-01-01'`), the query optimizer can often determine which partition(s) contain the relevant data and **scan only those partitions**, ignoring the others. This "partition elimination" can drastically reduce I/O and improve query performance on very large tables.
*   **Data Availability:** Maintenance operations (like index rebuilds) can sometimes be performed on individual partitions, potentially reducing the impact on the availability of the rest of the table.
*   **Storage Management:** Partitions can be mapped to different filegroups, allowing you to place different parts of a large table on different physical storage tiers (e.g., older data on slower, cheaper storage).

**Key Components:**

1.  **Partition Function:** Defines the boundaries and data type used to partition the data (e.g., `RANGE RIGHT FOR VALUES ('2020-01-01', '2021-01-01', ...)`).
2.  **Partition Scheme:** Maps the partitions defined by the partition function to specific filegroups where the data for each partition will be stored.
3.  **Partitioned Table/Index:** A table or index created `ON` the partition scheme, specifying the partitioning column.

## 2. Partitioning in Action: Analysis of `52_PARTITIONS.sql`

This script demonstrates the lifecycle of creating and managing partitioned tables.

**a) Creating Partition Function (`CREATE PARTITION FUNCTION`)**

```sql
CREATE PARTITION FUNCTION YearlyPartitionFunction (DATE) -- Data type of partitioning column
AS RANGE RIGHT FOR VALUES ('2020-01-01', '2021-01-01', ...); -- Boundary points
```

*   **Explanation:** Defines how data will be divided.
    *   `DATE`: Specifies the data type of the partitioning column.
    *   `RANGE RIGHT`: The boundary value belongs to the partition on its *right*. E.g., '2020-01-01' is the *first* value in the partition containing 2020 data. (`RANGE LEFT` means the boundary belongs to the partition on its left).
    *   `FOR VALUES (...)`: Lists the boundary points. `N` boundary points create `N+1` partitions. Here, dates before 2020 go to partition 1, 2020 data goes to partition 2, 2021 to partition 3, etc.

**b) Creating Partition Scheme (`CREATE PARTITION SCHEME`)**

```sql
CREATE PARTITION SCHEME YearlyPartitionScheme
AS PARTITION YearlyPartitionFunction -- Link to the function
ALL TO ([PRIMARY]); -- Map all partitions to the PRIMARY filegroup
-- Or TO (Filegroup1, Filegroup2, Filegroup3, ...)
```

*   **Explanation:** Maps the logical partitions created by the function to physical filegroups. `ALL TO ([PRIMARY])` maps all partitions to the default PRIMARY filegroup. In production, you'd typically create separate filegroups (e.g., `FG2020`, `FG2021`) and map partitions accordingly (`TO (FG_Pre2020, FG2020, FG2021, ...)`).

**c) Creating Partitioned Table**

```sql
CREATE TABLE HR.EmployeeAttendance (
    AttendanceID INT IDENTITY(1,1) NOT NULL,
    ...,
    AttendanceDate DATE NOT NULL, -- Partitioning column
    ...,
    CONSTRAINT PK_EmployeeAttendance PRIMARY KEY (AttendanceID, AttendanceDate) -- Partitioning key MUST be part of PK/Unique Index
) ON YearlyPartitionScheme(AttendanceDate); -- Specify scheme and partitioning column
```

*   **Explanation:** Creates the table `ON` the partition scheme, specifying the column (`AttendanceDate`) whose values will determine the partition for each row. **Crucially**, the partitioning column must be part of any unique index keys, including the primary key (often requiring a composite primary key if the partitioning column isn't naturally unique).

**d) Inserting Data**

*   **Explanation:** `INSERT` statements work normally. SQL Server automatically routes the row to the correct partition based on the value in the partitioning column (`AttendanceDate`) and the partition function definition.

**e) Querying Partition Information (System Views)**

```sql
SELECT p.partition_number, p.rows, prv.value AS boundary_value, fg.name AS filegroup_name
FROM sys.partitions p JOIN sys.indexes i ON ... JOIN sys.partition_schemes ps ON ...
JOIN sys.partition_functions pf ON ... LEFT JOIN sys.partition_range_values prv ON ...
JOIN sys.destination_data_spaces dds ON ... JOIN sys.filegroups fg ON ...
WHERE p.object_id = OBJECT_ID('HR.EmployeeAttendance') AND i.index_id <= 1 -- Clustered or Heap
ORDER BY p.partition_number;
```

*   **Explanation:** Uses various system views (`sys.partitions`, `sys.partition_schemes`, `sys.partition_functions`, `sys.partition_range_values`, etc.) to retrieve metadata about the partitions, including row counts per partition, boundary values, and the filegroup where each partition resides.

**f) Querying Specific Partitions (`$PARTITION`)**

```sql
SELECT ... FROM HR.EmployeeAttendance
WHERE $PARTITION.YearlyPartitionFunction(AttendanceDate) = 3; -- Select only from partition 3 (2021 data)
```

*   **Explanation:** The `$PARTITION.FunctionName(ColumnName)` syntax allows explicitly querying data based on the partition number it belongs to. Useful for administrative tasks or specific queries targeting a single partition.

**g) Partition Elimination**

```sql
SELECT ... FROM HR.EmployeeAttendance
WHERE AttendanceDate >= '2022-01-01' AND AttendanceDate < '2023-01-01';
```

*   **Explanation:** When a query's `WHERE` clause filters directly on the partitioning column (`AttendanceDate`) in a way that allows the optimizer to identify specific partitions, **partition elimination** occurs. The optimizer generates a plan that only accesses the relevant partitions (in this case, the partition containing 2022 data), significantly improving performance by avoiding scans of other partitions.

**h) Adding a Partition (`ALTER PARTITION FUNCTION ... SPLIT RANGE`)**

```sql
-- Add a boundary for 2025, creating a new partition for 2025+ data
ALTER PARTITION FUNCTION YearlyPartitionFunction() SPLIT RANGE ('2025-01-01');
-- Note: Requires the partition scheme to have a 'NEXT USED' filegroup specified, or use ALTER PARTITION SCHEME first.
```

*   **Explanation:** Adds a new boundary point to the partition function, effectively splitting an existing partition (usually the last one for `RANGE RIGHT` or first one for `RANGE LEFT`) to create a new, empty partition. Essential for adding new time periods in sliding window scenarios.

**i) Merging Partitions (`ALTER PARTITION FUNCTION ... MERGE RANGE`)**

```sql
-- Remove the '2020-01-01' boundary, merging data < 2020 with 2020 data
ALTER PARTITION FUNCTION YearlyPartitionFunction() MERGE RANGE ('2020-01-01');
```

*   **Explanation:** Removes a boundary point, merging the data from the two partitions adjacent to that boundary into a single partition. Often used to combine older partitions.

**j) Switching Partitions (`ALTER TABLE ... SWITCH PARTITION`)**

```sql
-- Create staging table with identical structure & constraints on the SAME filegroup as the target partition
CREATE TABLE HR.EmployeeAttendance_Staging (...);
-- Move data FROM partition 6 INTO the staging table
ALTER TABLE HR.EmployeeAttendance SWITCH PARTITION 6 TO HR.EmployeeAttendance_Staging;
-- Move data FROM a (pre-populated) staging table INTO an empty partition
-- ALTER TABLE HR.EmployeeAttendance_Staging SWITCH TO HR.EmployeeAttendance PARTITION 7;
```

*   **Explanation:** A very fast, **metadata-only** operation to move an entire partition's data between tables.
    *   `SWITCH OUT`: Moves data from a partition in the main table to an empty staging table. Used for archiving old data quickly.
    *   `SWITCH IN`: Moves data from a staging table (which must contain data only for the target partition's range and be empty otherwise) into an empty partition of the main table. Used for loading new data quickly.
*   **Requirements:** Tables must have identical structure (columns, data types), constraints (except FKs sometimes), and reside on the same filegroup as the partition being switched. The target partition/table must be empty for the switch direction.

**k) Creating Partitioned Indexes**

```sql
CREATE NONCLUSTERED INDEX IX_EmployeeAttendance_EmployeeID
ON HR.EmployeeAttendance(EmployeeID)
ON YearlyPartitionScheme(AttendanceDate); -- Align index with table partitioning
```

*   **Explanation:** Non-clustered indexes on partitioned tables can (and usually should) be **partition-aligned** by creating them `ON` the same partition scheme using the same partitioning column. This allows index maintenance per partition and potentially improves query performance.

**l) Partition-Aligned Indexed Views**

*   **Explanation:** Indexed views can be created on partitioned tables, and if designed correctly (partitioning key included in view definition and group by), the indexed view itself can be partitioned using the same scheme, allowing partition elimination benefits even when querying the view.

**m) Partitioning by Multiple Columns (Not Directly Supported)**

*   **Explanation:** SQL Server only supports partitioning based on a **single** column value. The script shows creating a table partitioned by `DepartmentID`, but this is independent of the date partitioning. True multi-column partitioning isn't directly supported; workarounds might involve computed columns combining multiple values or more complex designs.

**n/o) Partition Maintenance and Statistics**

```sql
ALTER INDEX PK_EmployeeAttendance ON HR.EmployeeAttendance REBUILD PARTITION = 3;
UPDATE STATISTICS HR.EmployeeAttendance WITH RESAMPLE ON PARTITIONS(5);
```

*   **Explanation:** Index maintenance (`REBUILD`, `REORGANIZE`) and statistics updates (`UPDATE STATISTICS`) can be performed on individual partitions, reducing the scope and duration of these operations compared to maintaining the entire table.

**p) Sliding Window Scenario**

*   **Explanation:** Outlines the typical steps for managing time-based partitioned data: create staging tables for new/old data, add a new partition boundary (`SPLIT`), switch new data in, switch old data out, remove the oldest boundary (`MERGE`). This keeps the main table focused on relevant data while efficiently handling new and archived data.

## 3. Targeted Interview Questions (Based on `52_PARTITIONS.sql`)

**Question 1:** What are the three main components required to create a partitioned table in SQL Server?

**Solution 1:**
1.  **Partition Function:** Defines the data type and boundary values used to divide the data. (`CREATE PARTITION FUNCTION ...`)
2.  **Partition Scheme:** Maps the logical partitions created by the function to physical filegroups. (`CREATE PARTITION SCHEME ...`)
3.  **Partitioned Table/Index:** The table or index created `ON` the partition scheme, specifying the partitioning column. (`CREATE TABLE ... ON PartitionSchemeName(ColumnName)`).

**Question 2:** What is "partition elimination," and how does it improve query performance?

**Solution 2:** Partition elimination is a query optimization technique where SQL Server determines, based on the `WHERE` clause filtering on the partitioning column, that only a subset of the table's partitions needs to be accessed to satisfy the query. By scanning only the relevant partitions and ignoring (eliminating) the others, SQL Server significantly reduces the amount of I/O required, leading to faster query execution times, especially on very large tables.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Can a table have multiple partition functions applied to it?
    *   **Answer:** No. A table can be partitioned based on only **one** partition function and scheme, using a single partitioning column (or a computed column based on multiple columns).
2.  **[Easy]** What command is used to move data efficiently between a staging table and a partition of a partitioned table?
    *   **Answer:** `ALTER TABLE ... SWITCH PARTITION ... TO ...`.
3.  **[Medium]** What is the difference between `RANGE LEFT` and `RANGE RIGHT` when defining a partition function?
    *   **Answer:** They determine which partition the boundary value itself belongs to:
        *   `RANGE LEFT`: The boundary value belongs to the partition on its **left**. The first partition holds values less than or equal to the first boundary.
        *   `RANGE RIGHT`: The boundary value belongs to the partition on its **right**. The first partition holds values strictly less than the first boundary. (Used in the script example).
4.  **[Medium]** What constraint must typically be met regarding the partitioning column and the table's primary key or unique constraints?
    *   **Answer:** The partitioning column **must** be included as part of any unique index key, including the primary key, on the partitioned table. This often requires creating composite primary/unique keys if the partitioning column isn't naturally unique.
5.  **[Medium]** Is the `ALTER TABLE ... SWITCH PARTITION` operation fully logged or minimally logged? What does this mean for performance?
    *   **Answer:** It is a **metadata-only** operation. It simply updates pointers in the system metadata to indicate which object owns the data extent. It does not physically move data pages, making it extremely fast and minimally logged, regardless of the partition size.
6.  **[Medium]** Can you query data directly from a specific partition number without knowing the boundary values?
    *   **Answer:** Yes, using the `$PARTITION` function in the `WHERE` clause (e.g., `WHERE $PARTITION.MyPartitionFunction(PartitioningColumn) = N`).
7.  **[Hard]** What are the requirements for a non-clustered index to be "partition-aligned"? Why is alignment generally beneficial?
    *   **Answer:** A non-clustered index is partition-aligned if it is created using the **same partition scheme** and the **same partitioning column** as its base table (or clustered index). Alignment is beneficial because it allows SQL Server to manage the index partitions alongside the table partitions (e.g., switching partitions affects both table and aligned indexes simultaneously), enables partition elimination on the non-clustered index itself, and allows for partition-level index maintenance (`REBUILD`/`REORGANIZE PARTITION = ...`).
8.  **[Hard]** What happens during an `ALTER PARTITION FUNCTION ... SPLIT RANGE` operation? What are the potential performance impacts?
    *   **Answer:** `SPLIT RANGE` introduces a new boundary value, effectively splitting one existing partition into two. This involves:
        *   Creating a new empty partition (usually on the 'NEXT USED' filegroup).
        *   Potentially **moving data** from the original partition into the newly created partition if existing rows now fall on the "wrong" side of the new boundary based on the `RANGE LEFT`/`RIGHT` definition.
    *   **Performance Impact:** If data movement is required (which is common when splitting a non-empty partition, especially the last one with `RANGE RIGHT`), the operation can be resource-intensive and logged, potentially causing blocking. Splitting an *empty* partition is a fast metadata operation.
9.  **[Hard]** What happens during an `ALTER PARTITION FUNCTION ... MERGE RANGE` operation? What are the potential performance impacts?
    *   **Answer:** `MERGE RANGE` removes an existing boundary value, combining the data from the two partitions adjacent to that boundary into a single partition. This involves:
        *   Updating metadata to reflect the new partition structure.
        *   Potentially **moving data** from one of the original partitions into the other remaining partition.
    *   **Performance Impact:** Similar to `SPLIT`, if data movement is required (merging two non-empty partitions), the operation can be resource-intensive and logged. Merging into an *empty* partition (after switching data out) is a fast metadata operation.
10. **[Hard/Tricky]** Can you partition a table based on a computed column? If so, are there any restrictions?
    *   **Answer:** Yes, you can partition a table based on a computed column. However, the computed column **must be marked as `PERSISTED`**. This ensures the value is physically stored and deterministic, allowing SQL Server to reliably determine the correct partition for each row based on the computed value. You cannot partition directly on a non-persisted computed column.
