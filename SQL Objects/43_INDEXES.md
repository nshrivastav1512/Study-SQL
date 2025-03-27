# SQL Deep Dive: Indexes

## 1. Introduction: What are Indexes?

Indexes are special database objects associated with tables or views that **speed up data retrieval operations** (`SELECT` queries, `JOIN` conditions, `WHERE` clauses). Think of them like the index in the back of a book: instead of scanning every page (the entire table), you can use the index to quickly locate the specific information (rows) you need.

**Why use Indexes?**

*   **Performance:** The primary reason. Well-designed indexes drastically reduce the time it takes to find data, especially in large tables, by avoiding full table scans.
*   **Uniqueness:** Unique indexes (including primary keys) enforce data integrity by preventing duplicate values in the indexed columns.

**How do they work (simplified)?**

Indexes typically store a copy of the indexed column(s) along with a pointer (like a row ID or the clustered key value) back to the original data row. This index data is usually stored in a sorted structure (like a B-tree) that allows SQL Server to efficiently search for specific values or ranges.

**Trade-offs:**

*   **Storage:** Indexes consume additional disk space.
*   **DML Overhead:** Indexes need to be maintained whenever data in the table is modified (`INSERT`, `UPDATE`, `DELETE`), which adds overhead to these operations. Finding the right balance between read performance gains and write performance overhead is key.

## 2. Index Types and Operations in Action: Analysis of `43_INDEXES.sql`

This script demonstrates creating and managing various index types and options.

**a) Clustered Index (`CREATE CLUSTERED INDEX`)**

```sql
CREATE TABLE ProjectTeam (...);
CREATE CLUSTERED INDEX CIX_ProjectTeam_TeamID ON ProjectTeam(TeamID);
-- Note: PRIMARY KEY constraint often creates a clustered index by default.
```

*   **Explanation:** Defines the **physical storage order** of the data rows in the table based on the key column(s) (`TeamID`). A table can have **only one** clustered index. The actual table data is stored at the leaf level of the clustered index.

**b) Non-Clustered Index (`CREATE NONCLUSTERED INDEX`)**

```sql
CREATE NONCLUSTERED INDEX IX_ProjectTeam_TeamName ON ProjectTeam(TeamName);
```

*   **Explanation:** Creates a separate structure (usually a B-tree) containing the indexed column(s) (`TeamName`) and pointers back to the data rows (either the clustered key or a Row ID if the table is a heap). A table can have **multiple** (up to 999) non-clustered indexes. They speed up queries filtering or sorting on the indexed columns without dictating the physical table order.

**c) Unique Index (`CREATE UNIQUE INDEX`)**

```sql
CREATE UNIQUE INDEX UIX_ProjectTeam_TeamName ON ProjectTeam(TeamName);
-- Or CREATE UNIQUE NONCLUSTERED INDEX ...
```

*   **Explanation:** A non-clustered (or clustered) index that also enforces uniqueness on the values in the key column(s). Prevents duplicate `TeamName` values.

**d) Composite Index (Multi-Column)**

```sql
CREATE NONCLUSTERED INDEX IX_Projects_StatusStartDate ON Projects(Status, StartDate);
```

*   **Explanation:** An index based on **multiple columns**. The order matters (`Status` first, then `StartDate`). Useful for queries filtering or sorting on both columns, especially `WHERE Status = 'X' AND StartDate > 'Y'` or `ORDER BY Status, StartDate`.

**e) Index with Included Columns (`INCLUDE`)**

```sql
CREATE NONCLUSTERED INDEX IX_Projects_Name_IncludeBudget ON Projects(ProjectName) INCLUDE (Budget, Status);
```

*   **Explanation:** Creates a non-clustered index on `ProjectName`. The `INCLUDE` clause adds `Budget` and `Status` to the **leaf level** of the index. This helps create **covering indexes**: if a query selects `ProjectName`, `Budget`, `Status` and filters on `ProjectName`, it can get all required data from the index without accessing the base table. Included columns are not part of the index key used for sorting/searching.

**f) Filtered Index (`WHERE`)**

```sql
CREATE NONCLUSTERED INDEX IX_Projects_HighBudget ON Projects(ProjectName, Budget) WHERE Budget > 100000;
```

*   **Explanation:** An index that only includes rows meeting the specified `WHERE` condition (`Budget > 100000`). This creates a smaller, potentially more efficient index if queries frequently target that specific subset of data.

**g/h) Columnstore Index (`CREATE [CLUSTERED | NONCLUSTERED] COLUMNSTORE INDEX`)**

```sql
CREATE CLUSTERED COLUMNSTORE INDEX CCI_ProjectAnalytics ON ProjectAnalytics;
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_Projects_Budget_Dates ON Projects(Budget, StartDate, EndDate);
```

*   **Explanation:** Stores data column-wise, highly compressed, and processed in batches. Optimized for analytical (OLAP) queries involving large scans and aggregations. Can be clustered (the entire table storage) or nonclustered (an additional index containing specific columns).

**i) Spatial Index (`CREATE SPATIAL INDEX`)**

```sql
CREATE SPATIAL INDEX SIX_ProjectLocations_GeoLocation ON ProjectLocations(GeoLocation) USING GEOGRAPHY_GRID;
```

*   **Explanation:** Optimizes queries using spatial data types (`geometry`, `geography`) and methods (e.g., finding points within a distance or area). Requires specifying a tessellation scheme (like `GEOGRAPHY_GRID`).

**j) Full-Text Index (`CREATE FULLTEXT INDEX`)**

```sql
CREATE FULLTEXT CATALOG ProjectFTCatalog AS DEFAULT;
CREATE FULLTEXT INDEX ON ProjectDocumentation(DocumentContent) KEY INDEX PK_... WITH STOPLIST = SYSTEM;
```

*   **Explanation:** Enables fast linguistic searches (word forms, proximity, relevance) on text-based columns (`VARCHAR`, `NVARCHAR`, `VARBINARY`, `XML`, `FILESTREAM`). Requires a Full-Text Catalog and specifies the unique key index of the table.

**k) XML Index (`CREATE [PRIMARY | XML] INDEX`)**

```sql
CREATE PRIMARY XML INDEX PIX_... ON ProjectXMLData(XMLData);
CREATE XML INDEX SIX_... ON ProjectXMLData(XMLData) USING XML INDEX PIX_... FOR PATH;
```

*   **Explanation:** Optimizes queries using XQuery methods against `XML` data type columns. Requires a primary XML index first, then secondary XML indexes (PATH, VALUE, PROPERTY) can be created for specific query patterns.

**l) Index with Fill Factor (`WITH (FILLFACTOR = ...)`**

```sql
CREATE NONCLUSTERED INDEX ... ON ... WITH (FILLFACTOR = 80);
```

*   **Explanation:** Specifies the percentage of space on each leaf-level index page to be filled during index creation/rebuild. A lower fill factor (e.g., 80%) leaves more free space on pages, reducing page splits during subsequent `INSERT`s and `UPDATE`s (good for write-heavy tables), but increases index size. A higher fill factor (closer to 100, the default) saves space but can lead to more page splits if data is frequently inserted/updated in the middle of the index range.

**m) Index with Data Compression (`WITH (DATA_COMPRESSION = ...)`**

```sql
CREATE NONCLUSTERED INDEX ... ON ... WITH (DATA_COMPRESSION = PAGE); -- Or ROW
```

*   **Explanation:** Applies row or page compression to the index data to save storage space and potentially improve I/O performance (fewer pages to read). Increases CPU usage for compression/decompression.

**n) Index on Computed Column**

```sql
ALTER TABLE Projects ADD ProjectDurationDays AS DATEDIFF(DAY, StartDate, EndDate); -- Can be PERSISTED
CREATE NONCLUSTERED INDEX IX_Projects_Duration ON Projects(ProjectDurationDays);
```

*   **Explanation:** You can create indexes on computed columns, allowing queries filtering on the computed value to perform seeks. The computed column must be deterministic and meet certain criteria. Indexing is often more efficient if the computed column is also marked `PERSISTED`.

**o) Altering an Index (`ALTER INDEX`)**

```sql
ALTER INDEX IX_... ON Projects DISABLE; -- Temporarily disable (stops usage & maintenance)
ALTER INDEX IX_... ON Projects REBUILD; -- Recreate the index (removes fragmentation)
ALTER INDEX ALL ON Projects REBUILD; -- Rebuild all indexes on the table
ALTER INDEX IX_... ON Projects REORGANIZE; -- Defragment leaf level (online, less intensive)
```

*   **Explanation:** Commands for index maintenance. `DISABLE` makes an index unusable. `REBUILD` drops and recreates it (offline by default in Standard Ed.). `REORGANIZE` defragments the leaf pages online.

**p) Dropping an Index (`DROP INDEX`)**

```sql
DROP INDEX IX_Projects_HighBudget ON Projects;
```

*   **Explanation:** Permanently removes an index definition and its associated data structures.

**q/r/s) Index Creation Options (`ONLINE`, `SORT_IN_TEMPDB`, `PAD_INDEX`, etc.)**

```sql
CREATE NONCLUSTERED INDEX ... ON ... WITH (ONLINE = ON, SORT_IN_TEMPDB = ON, FILLFACTOR = 90, ...);
```

*   **Explanation:** Various `WITH` options control how an index is created or rebuilt:
    *   `ONLINE = ON`: (Enterprise Ed. mostly) Allows concurrent DML operations on the table while the index is being created/rebuilt. Reduces blocking but takes longer and uses more resources.
    *   `SORT_IN_TEMPDB = ON`: Uses `tempdb` for intermediate sort operations during index creation, potentially reducing contention on the user database's log file and data files if `tempdb` is on separate storage.
    *   `PAD_INDEX = ON`: Applies the specified `FILLFACTOR` percentage to intermediate index pages, not just the leaf level.
    *   `STATISTICS_NORECOMPUTE = ON`: Disables automatic statistics updates for this index (rarely recommended).
    *   `DROP_EXISTING = ON`: Atomically drops the old index and creates the new one with the same name but potentially different definition (useful for changing index structure without intermediate state).
    *   `ALLOW_ROW_LOCKS`/`ALLOW_PAGE_LOCKS`: Control lock granularity allowed on the index.

**t) Viewing Index Information (System Views/DMVs)**

```sql
-- Index definitions
SELECT ... FROM sys.indexes i JOIN sys.index_columns ic ON ... WHERE OBJECT_NAME(i.object_id) = 'Projects';
-- Index usage
SELECT ... FROM sys.indexes i LEFT JOIN sys.dm_db_index_usage_stats ius ON ... WHERE ...;
-- Index fragmentation
SELECT ... FROM sys.dm_db_index_physical_stats(...) ips JOIN sys.indexes i ON ... WHERE ...;
```

*   **Explanation:** Queries using system views (`sys.indexes`, `sys.index_columns`) and DMVs (`sys.dm_db_index_usage_stats`, `sys.dm_db_index_physical_stats`) to retrieve metadata about index definitions, track their usage (seeks, scans, updates), and check their fragmentation levels. Essential for index analysis and maintenance.

## 3. Targeted Interview Questions (Based on `43_INDEXES.sql`)

**Question 1:** What is the difference between a clustered and a non-clustered index in terms of data storage? How many of each can a table have?

**Solution 1:**

*   **Clustered Index:** Defines the physical storage order of the table data based on its key values. The actual data rows reside at the leaf level of the clustered index. A table can have **only one** clustered index.
*   **Non-Clustered Index:** A separate structure containing the index key values and pointers (row locators) back to the actual data rows (which are stored either in the clustered index or a heap). A table can have **multiple** (up to 999) non-clustered indexes.

**Question 2:** What is the purpose of the `INCLUDE` clause in a `CREATE NONCLUSTERED INDEX` statement? How does it help create a "covering" index?

**Solution 2:** The `INCLUDE` clause allows you to add non-key columns to the leaf level of a non-clustered index. These columns are not part of the index key (used for sorting/searching) but are stored alongside the key and row locator at the leaf. This helps create a covering index because if a query needs columns that are part of the index key *or* the `INCLUDE` clause, and the `WHERE`/`JOIN` conditions can be satisfied by the index key, SQL Server can retrieve all necessary data directly from the index pages without having to perform an additional lookup to the base table, thus improving query performance.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Does creating a `PRIMARY KEY` constraint typically create an index? If so, what kind?
    *   **Answer:** Yes, by default, creating a `PRIMARY KEY` constraint creates a **unique clustered index** on the primary key column(s). You can explicitly specify `NONCLUSTERED` if desired.
2.  **[Easy]** Can you create an index on a view?
    *   **Answer:** Yes, but only on views created `WITH SCHEMABINDING`. You must first create a unique clustered index on the view (which materializes it), after which you can create additional non-clustered indexes. This creates an **indexed view**.
3.  **[Medium]** What is index fragmentation, and why is it bad for performance? Name two types.
    *   **Answer:** Index fragmentation occurs when the logical order of pages in an index does not match the physical storage order, or when index pages have excessive free space due to data modifications (inserts, updates, deletes). It's bad because it can lead to increased I/O (more pages need to be read for scans) and less efficient use of the buffer cache.
        *   **External Fragmentation:** Logical order of pages differs from physical order. Affects scan performance.
        *   **Internal Fragmentation:** Index pages have excessive free space. Wastes space and requires more pages to be read.
4.  **[Medium]** What is the difference between `ALTER INDEX ... REBUILD` and `ALTER INDEX ... REORGANIZE`? Which is typically done online?
    *   **Answer:**
        *   `REBUILD`: Drops and recreates the index. Removes all fragmentation. More resource-intensive. Can be done `ONLINE` in Enterprise Edition (reduces blocking but takes longer).
        *   `REORGANIZE`: Defragments the leaf level of the index *in place* by physically reordering pages. Less resource-intensive. Always an **online** operation. Less effective for high fragmentation than `REBUILD`.
5.  **[Medium]** What does the `FILLFACTOR` option control? When might you set it below 100?
    *   **Answer:** `FILLFACTOR` controls the percentage of space on each leaf-level index page that is filled with data when the index is created or rebuilt. Setting it below 100 (e.g., 80 or 90) leaves free space on the pages. This is beneficial for tables with frequent `INSERT`s or `UPDATE`s that increase data size, as the free space can accommodate new/expanded rows without causing frequent **page splits** (which are performance-intensive and cause fragmentation). The trade-off is increased index size.
6.  **[Medium]** Can you create an index on a temporary table (`#temp`)? Can you create one on a table variable (`@table`)?
    *   **Answer:** Yes, you can create indexes (clustered and non-clustered) on temporary tables (`#temp`) after they are created. No, you generally cannot create explicit non-clustered indexes on table variables (`@table`), although you can define `PRIMARY KEY` and `UNIQUE` constraints inline, which implicitly create underlying index structures. (Note: Newer SQL Server versions have some enhancements like deferred compilation for table variables that can improve performance).
7.  **[Hard]** What is a filtered index, and in what scenario is it particularly useful?
    *   **Answer:** A filtered index is a non-clustered index that includes only a subset of rows from the table, defined by a `WHERE` clause in the index definition. It's useful when queries frequently access a specific, well-defined subset of data (e.g., `WHERE Status = 'Active'`, `WHERE OrderDate >= '2023-01-01'`). Because the index only contains data for matching rows, it is smaller and potentially faster to scan or seek into than a full index on the same columns, and requires less maintenance overhead.
8.  **[Hard]** What is the difference between key columns and included columns in a non-clustered index? How does it affect index size and usage?
    *   **Answer:**
        *   **Key Columns:** Define the structure and sort order of the index B-tree. They are stored at all levels of the index (root, intermediate, leaf). Used for seeking and sorting. Limited in total size and number of columns.
        *   **Included Columns:** Stored *only* at the leaf level of the index along with the key columns and row locator. They are *not* part of the index key and don't affect the index sort order. Their primary purpose is to create covering indexes by including columns needed in the `SELECT` list, avoiding key lookups. They have fewer restrictions on data types and total size compared to key columns.
        *   **Impact:** Key columns increase the size of all index levels; included columns only increase the size of the leaf level. Both contribute to covering queries.
9.  **[Hard]** Explain the purpose of `SORT_IN_TEMPDB = ON` when creating or rebuilding an index.
    *   **Answer:** When creating or rebuilding a large index, SQL Server needs to sort the index key data. By default, this sort operation occurs within the user database, potentially consuming significant space and I/O in the user database's transaction log and data files. `SORT_IN_TEMPDB = ON` directs SQL Server to perform the intermediate sort operations in the `tempdb` database instead. If `tempdb` is located on a separate, faster storage subsystem, this can speed up the index build process and reduce I/O contention and log growth within the user database.
10. **[Hard/Tricky]** Can creating too many indexes on a table negatively impact performance? If so, how?
    *   **Answer:** Yes. While indexes speed up reads (`SELECT`), they slow down data modifications (`INSERT`, `UPDATE`, `DELETE`). Every non-clustered index must be updated whenever data in its key columns (or sometimes included columns or the base table row location) changes. Having too many indexes means:
        *   **Increased DML Overhead:** `INSERT`, `UPDATE`, `DELETE` operations become slower as more index structures need to be maintained.
        *   **Increased Storage:** More indexes consume more disk space and memory (buffer pool).
        *   **Potential Optimizer Confusion:** While usually good, having many overlapping or redundant indexes could potentially confuse the optimizer or lead to slightly less optimal plan choices in some edge cases (though this is less common than the DML overhead).
    *   The goal is to find the right balance, creating only the indexes that provide significant benefit to critical read queries while considering the impact on write performance.
