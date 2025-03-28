# SQL Deep Dive: Table Partitioning (Comprehensive)

## 1. Introduction: What is Table Partitioning?

Table Partitioning is a feature in SQL Server (primarily Enterprise Edition) that allows you to divide large tables and indexes into smaller, more manageable units called **partitions**, while still querying them as a single logical entity. Data is horizontally partitioned based on the value ranges of a specific **partitioning column**.

**Why Partition?**

*   **Manageability:** Simplifies managing large datasets. Operations like loading new data, archiving old data, or performing index maintenance can target individual partitions, making them faster and less resource-intensive than operating on the entire table.
*   **Performance:** Enables **partition elimination**, where the query optimizer accesses only the relevant partitions based on the query's `WHERE` clause filtering on the partitioning column, significantly reducing I/O and improving query speed.
*   **Availability:** Allows maintenance operations (e.g., index rebuilds) to be performed on individual partitions, potentially online, minimizing downtime for the rest of the table.
*   **Storage Tiering:** By mapping partitions to different filegroups, you can place older, less frequently accessed data on slower, cheaper storage and current data on faster storage.

**Key Components:**

1.  **Partition Function:** Defines the data type of the partitioning column and the boundary values that separate the partitions (`CREATE PARTITION FUNCTION`). Uses `RANGE LEFT` or `RANGE RIGHT` to specify which side of the boundary the value belongs to.
2.  **Partition Scheme:** Maps the logical partitions defined by the function to physical filegroups (`CREATE PARTITION SCHEME`). Can map all partitions to one filegroup or different partitions to different filegroups. Must specify a `NEXT USED` filegroup for future `SPLIT` operations.
3.  **Partitioned Table/Index:** The table or index created `ON` the partition scheme, specifying the partitioning column. The partitioning column must be part of any unique index/primary key.

## 2. Partitioning in Action: Analysis of `68_PARTITIONING.sql`

This script provides a detailed walkthrough of implementing and managing partitioning.

**Part 1: Fundamentals**

*   Explains the concept, benefits (performance, manageability, availability), and key components (Function, Scheme, Table/Index).

**Part 2: Setting Up Partitioning**

*   **1. Create Filegroups:** (Optional but recommended) Demonstrates creating multiple filegroups (`FG_Archive`, `FG_Historical`, `FG_Current`, `FG_Future`) and adding data files (`.ndf`) to them. This allows physical separation of partitions.
*   **2. Create Partition Function:** Defines the partitioning logic.
    ```sql
    CREATE PARTITION FUNCTION PF_OrderDate_Yearly(DATE) -- Partitioning column type
    AS RANGE RIGHT -- Boundary value belongs to partition on the right
    FOR VALUES ('2020-01-01', '2021-01-01', '2022-01-01', '2023-01-01');
    -- Creates 5 partitions: P1(<2020), P2(2020), P3(2021), P4(2022), P5(>=2023)
    ```
*   **3. Create Partition Scheme:** Maps function partitions to filegroups.
    ```sql
    CREATE PARTITION SCHEME PS_OrderDate_Yearly
    AS PARTITION PF_OrderDate_Yearly
    TO (FG_Archive, FG_Historical, FG_Historical, FG_Current, FG_Future);
    -- Maps P1->FG_Archive, P2->FG_Historical, P3->FG_Historical, P4->FG_Current, P5->FG_Future
    -- Need NEXT USED for future splits: ALTER PARTITION SCHEME ... NEXT USED FG_Future;
    ```

**Part 3: Creating Partitioned Tables**

*   **1. New Partitioned Table:** Creates a table directly `ON` the partition scheme, specifying the partitioning column. The partitioning column (`OrderDate`) must be part of the primary key.
    ```sql
    CREATE TABLE HR.OrdersPartitioned (..., OrderDate DATE NOT NULL, ...,
        CONSTRAINT PK_OrdersPartitioned PRIMARY KEY CLUSTERED (OrderDate, OrderID)
    ) ON PS_OrderDate_Yearly(OrderDate);
    ```
*   **2. Convert Existing Table:** Outlines steps to partition an existing table (create partitioned staging table, insert data, rename tables). Often involves downtime or complex online rebuilds.
*   **3. Partitioned Indexes:** Nonclustered indexes can (and usually should) be **partition-aligned** by creating them `ON` the same partition scheme and column. Non-aligned indexes are created on a single filegroup (like `PRIMARY`) and can hinder partition switching.
    ```sql
    -- Aligned index
    CREATE NONCLUSTERED INDEX IX_Orders_EmployeeID ON HR.OrdersPartitioned(EmployeeID, OrderDate) ON PS_OrderDate_Yearly(OrderDate);
    -- Non-aligned index (generally avoid unless specific reason)
    CREATE NONCLUSTERED INDEX IX_Orders_CustomerID ON HR.OrdersPartitioned(CustomerID) ON [PRIMARY];
    ```

**Part 4: Partition Management**

*   **1. Adding Partition (`SPLIT RANGE`):** Adds a new boundary point, splitting the last (for `RANGE RIGHT`) or first (for `RANGE LEFT`) partition. Requires `NEXT USED` filegroup on the scheme. Can involve data movement if splitting a non-empty partition.
    ```sql
    ALTER PARTITION SCHEME PS_OrderDate_Yearly NEXT USED FG_Future; -- Specify where new partition goes
    ALTER PARTITION FUNCTION PF_OrderDate_Yearly() SPLIT RANGE ('2024-01-01'); -- Add boundary
    ```
*   **2. Removing Partition (`MERGE RANGE`):** Removes a boundary point, merging two adjacent partitions. Can involve data movement if merging non-empty partitions.
    ```sql
    ALTER PARTITION FUNCTION PF_OrderDate_Yearly() MERGE RANGE ('2020-01-01'); -- Remove boundary
    ```
*   **3. Partition Switching (`ALTER TABLE ... SWITCH PARTITION`):** Fast, metadata-only operation to move entire partitions between tables.
    *   **Switch Out (Archiving):** Move data from a partition (e.g., partition 1) to an empty, identically structured staging/archive table.
        ```sql
        ALTER TABLE HR.OrdersPartitioned SWITCH PARTITION 1 TO HR.Orders_Archive;
        ```
    *   **Switch In (Loading):** Move data from a staging table (containing data only for the target partition range) into an *empty* partition.
        ```sql
        ALTER TABLE HR.Orders_2023Q1 SWITCH TO HR.OrdersPartitioned PARTITION 6;
        ```
    *   **Requirements:** Tables must be structure/constraint-identical (mostly), on the same filegroup as the partition, target must be empty. Non-aligned indexes prevent switching.

**Part 5: Querying Partitioned Tables**

*   **1. Partition Elimination:** The key performance benefit. If the `WHERE` clause filters on the partitioning column, the optimizer can identify and access only the necessary partitions.
*   **2. Viewing Metadata:** Uses system views (`sys.partitions`, `sys.partition_schemes`, `sys.partition_functions`, `sys.partition_range_values`, etc.) to see partition details, row counts, boundaries, and filegroups.
*   **3. Finding Partition (`$PARTITION`):** Use `$PARTITION.FunctionName(ColumnName)` in `SELECT` or `WHERE` to identify the partition number for specific rows or query a specific partition.

**Part 6: Sliding Window Scenario**

*   **Concept:** Common pattern for time-based data (e.g., keep 24 months online). Regularly add a new partition for the upcoming period, switch new data in, switch the oldest partition out to an archive table, and merge the now-empty oldest partition range.
*   **Implementation:** Provides a stored procedure (`HR.Maintain_OrderPartitions`) outlining the steps: identify partition to archive, create staging table, `SWITCH OUT` old data, `MERGE RANGE` old boundary, set `NEXT USED`, `SPLIT RANGE` for new boundary, potentially `SWITCH IN` new data (though the example switches out first), move staged data to final archive, drop staging table.

## 3. Targeted Interview Questions (Based on `68_PARTITIONING.sql`)

**Question 1:** What are the three main components required to create a partitioned table in SQL Server?

**Solution 1:**
1.  **Partition Function:** Defines the data type and boundary values used to divide the data. (`CREATE PARTITION FUNCTION ...`)
2.  **Partition Scheme:** Maps the logical partitions created by the function to physical filegroups. (`CREATE PARTITION SCHEME ...`)
3.  **Partitioned Table/Index:** The table or index created `ON` the partition scheme, specifying the partitioning column. (`CREATE TABLE ... ON PartitionSchemeName(ColumnName)`).

**Question 2:** Explain the `ALTER TABLE ... SWITCH PARTITION` command. Why is it significantly faster than using `INSERT`/`DELETE` for moving large amounts of data (like archiving)?

**Solution 2:** `ALTER TABLE ... SWITCH PARTITION` is a command used to move an entire data partition between two tables (typically a partitioned table and a staging/archive table). It is significantly faster because it's a **metadata-only operation**. It doesn't physically move the data pages; instead, it just updates the internal metadata pointers to indicate that the data extent now belongs to the target table/partition instead of the source. Because no data is physically moved or logged row-by-row, the operation completes almost instantaneously, regardless of the size of the partition, unlike `INSERT`/`DELETE` which involves physically copying/removing rows and extensive transaction logging.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Can a table have multiple partition functions applied to it?
    *   **Answer:** No. A table can be partitioned based on only **one** partition function and scheme, using a single partitioning column (or a computed column based on multiple columns).
2.  **[Easy]** What command is used to move data efficiently between a staging table and a partition of a partitioned table?
    *   **Answer:** `ALTER TABLE ... SWITCH PARTITION ... TO ...`.
3.  **[Medium]** What is the difference between `RANGE LEFT` and `RANGE RIGHT` in a partition function definition?
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
