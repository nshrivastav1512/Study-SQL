# SQL Deep Dive: Index Fill Factor

## 1. Introduction: What is Fill Factor?

**Fill Factor** is an index creation and maintenance option in SQL Server that specifies the percentage of space on each leaf-level page of an index that should be filled with data *when the index is created or rebuilt*. The remaining space is reserved for future growth (inserts and updates that increase row size).

**Why is Fill Factor Important?**

*   **Page Splits:** When a new row needs to be inserted into a full index page (or an existing row expands due to an update), SQL Server must perform a **page split**. This involves allocating a new page, moving approximately half the rows from the full page to the new page, and updating pointers. Page splits are resource-intensive operations (I/O, logging, CPU) and can lead to **index fragmentation**.
*   **Controlling Free Space:** Fill Factor allows you to proactively leave empty space on index pages during index creation/rebuild. A lower fill factor leaves more free space, reducing the likelihood and frequency of page splits as new data is added or existing data expands.
*   **Performance Trade-off:**
    *   **Lower Fill Factor (e.g., 70%):** Reduces page splits and fragmentation, potentially improving `INSERT`/`UPDATE` performance, especially on tables with random inserts or frequent updates that increase row size. However, it makes the index larger (more pages required to store the same data), which can make read operations (scans) slightly less efficient as more pages need to be read.
    *   **Higher Fill Factor (e.g., 100% or 0):** Maximizes data density on each page, minimizing the index size and potentially improving read performance (fewer pages to read for scans). However, it leaves no room for growth, leading to more frequent page splits and fragmentation if the data is modified frequently.

**Default Value:** The server-wide default fill factor is 0, which is functionally equivalent to 100 (fill pages completely).

## 2. Fill Factor in Action: Analysis of `69_FILL_FACTOR.sql`

This script demonstrates how to configure and manage the fill factor setting.

**Part 1: Fundamentals**

*   Explains what fill factor is, how it works (percentage of page filled), the default value (0 or 100), and its primary purpose (managing free space to mitigate page splits).

**Part 2: Configuring Fill Factor**

*   **1. Server-Wide Default:**
    ```sql
    -- View current setting
    SELECT * FROM sys.configurations WHERE name = 'fill factor (%)';
    -- Change setting (requires advanced options & RECONFIGURE)
    -- EXEC sp_configure 'fill factor', 80; RECONFIGURE;
    ```
    *   **Explanation:** Sets the default fill factor used when creating or rebuilding indexes *without* explicitly specifying a `FILLFACTOR` option. Changing this requires `sp_configure`.
*   **2. Specific Index (`CREATE`/`ALTER INDEX ... WITH (FILLFACTOR = ...)`):**
    ```sql
    CREATE NONCLUSTERED INDEX IX_EMP_LastName ON HR.EMP_Details(LastName) WITH (FILLFACTOR = 80);
    ALTER INDEX IX_EMP_LastName ON HR.EMP_Details REBUILD WITH (FILLFACTOR = 75);
    ```
    *   **Explanation:** Specifies the fill factor for a particular index during creation or rebuild. This **overrides** the server-wide default.
*   **3. All Indexes on a Table (`ALTER INDEX ALL ... REBUILD WITH ...`):**
    ```sql
    ALTER INDEX ALL ON HR.EMP_Details REBUILD WITH (FILLFACTOR = 80);
    ```
    *   **Explanation:** Rebuilds *all* indexes on the specified table using the same fill factor setting.

**Part 3: Fill Factor and Workload Types**

*   **1. OLTP (High Inserts/Updates):** Recommends a **lower fill factor (e.g., 70-85%)** for indexes on frequently modified tables to leave space for new rows/expansions and reduce page splits.
*   **2. OLAP (Read-Heavy):** Recommends a **higher fill factor (e.g., 90-100%)** for indexes on tables that are read-mostly or static. This maximizes data density per page, reducing the number of pages needed for scans.
*   **3. Mixed Workload:** Suggests a **moderate fill factor (e.g., 80-90%)** as a starting point, requiring monitoring and tuning based on observed fragmentation and page split activity.

**Part 4: Monitoring Page Splits and Fragmentation**

*   **1. Monitoring Page Splits:** Mentions using trace flags (like 1222 for deadlocks, though page split specific ones exist but are less common) or querying DMVs like `sys.dm_db_index_operational_stats` (looking at `leaf_insert_count`, `leaf_update_count` relative to page structure) to infer page split activity, although direct split counts are harder to get easily. High insert/update counts on full pages often lead to splits.
*   **2. Monitoring Fragmentation:** Demonstrates querying `sys.dm_db_index_physical_stats` to check `avg_fragmentation_in_percent`. High fragmentation is often a consequence of page splits caused by inappropriate fill factor (usually too high for the workload).
*   **3. Correlation:** Implies that monitoring fragmentation over time, potentially alongside the fill factor setting (using `sys.indexes`), can help determine if the current fill factor is appropriate. The script includes a conceptual procedure (`HR.CaptureFragmentationMetrics`) to log this data.

**Part 5: Optimizing Fill Factor**

*   **1. Determining Optimal Value:** Emphasizes that the ideal fill factor is workload-dependent. Suggests testing different values (`ALTER INDEX ... REBUILD WITH (FILLFACTOR = X)`) and monitoring subsequent fragmentation levels and query performance under a representative workload.
*   **2. Automated Adjustment (Conceptual):** Provides an example procedure (`HR.OptimizeFillFactors`) that queries fragmentation levels and current fill factors. It suggests logic to *decrease* the fill factor (e.g., set to 90 or current - 10) for highly fragmented indexes with high fill factors, and *increase* it (e.g., set to current + 10) for indexes with low fragmentation and low fill factors. *Note: This is a conceptual example; real-world automation requires careful testing and consideration of maintenance windows.*

## 3. Targeted Interview Questions (Based on `69_FILL_FACTOR.sql`)

**Question 1:** What does setting `FILLFACTOR = 80` mean when creating or rebuilding an index?

**Solution 1:** It means that SQL Server will fill each leaf-level page of the index structure to approximately 80% capacity, leaving the remaining 20% of the page empty. This free space is reserved to accommodate future `INSERT` operations or `UPDATE`s that increase the size of existing rows on that page, thereby reducing the likelihood of immediate page splits.

**Question 2:** What is a page split, and why is reducing page splits generally desirable for performance?

**Solution 2:** A page split occurs when a data modification (`INSERT` or `UPDATE`) needs to add data to an index page that is already full. SQL Server allocates a new page, moves about half the rows from the full page to the new page, and updates pointers. Page splits are undesirable because:
1.  **Resource Intensive:** They consume significant I/O, CPU, and transaction log resources during the split operation itself.
2.  **Fragmentation:** They lead to logical fragmentation (pages out of order) and potentially low page density (pages only half full after the split), making subsequent index scans less efficient as more pages need to be read.
3.  **Blocking:** The process can require locks that block other concurrent operations.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** What is the default fill factor value in SQL Server if not specified? What does this value mean?
    *   **Answer:** The default is 0, which means 100% (fill pages completely).
2.  **[Easy]** Does fill factor apply only to the leaf level or all levels of an index?
    *   **Answer:** Fill factor primarily applies to the **leaf level** during index creation/rebuild. Intermediate levels might also have some space reserved, but the specified percentage directly controls leaf-level fullness.
3.  **[Medium]** If you set a fill factor of 70, will the pages always remain 70% full?
    *   **Answer:** No. The 70% fill is applied only during the `CREATE INDEX` or `ALTER INDEX ... REBUILD` operation. As subsequent `INSERT`s and `UPDATE`s occur, pages will gradually fill up beyond 70%. Once a page becomes full, a page split will occur if more data needs to be added to it.
4.  **[Medium]** Which operation respects the fill factor setting: `ALTER INDEX ... REBUILD` or `ALTER INDEX ... REORGANIZE`?
    *   **Answer:** `ALTER INDEX ... REBUILD`. Rebuilding drops and recreates the index structure, applying the specified (or default) fill factor. `REORGANIZE` only compacts data within existing pages and does not reapply the fill factor setting.
5.  **[Medium]** For a read-only data warehouse table, what would generally be a suitable fill factor setting and why?
    *   **Answer:** A fill factor of 100 (or 0) would generally be suitable. Since the data is read-only and won't be modified, there's no need to reserve free space for future growth. Filling pages completely minimizes the number of pages required to store the data, making index scans and table scans more efficient (less I/O).
6.  **[Medium]** Can you set a different fill factor for the clustered index and a nonclustered index on the same table?
    *   **Answer:** Yes. Fill factor is an option specified per index. You can rebuild the clustered index with one fill factor and rebuild or create nonclustered indexes with different fill factors using the `WITH (FILLFACTOR = ...)` clause in the respective `ALTER INDEX` or `CREATE INDEX` statements.
7.  **[Hard]** How does fill factor relate to index fragmentation?
    *   **Answer:** Fill factor directly influences the likelihood of page splits, which are a primary cause of index fragmentation (especially logical fragmentation, where the physical page order doesn't match the logical index order). A fill factor that is too high (close to 100%) for a table with frequent inserts/updates will lead to frequent page splits and thus higher fragmentation over time. A lower fill factor leaves more space, reducing splits and slowing the rate at which fragmentation builds up.
8.  **[Hard]** Does the fill factor setting apply to heaps (tables without a clustered index)?
    *   **Answer:** No. Fill factor is specifically an index setting that controls page fullness within the B-tree structure (both clustered and nonclustered indexes). Heaps do not have a defined logical order or the same page-filling mechanism controlled by fill factor during rebuilds. Data is simply added to available pages.
9.  **[Hard]** If you specify `FILLFACTOR = 50` when rebuilding an index, does this mean `INSERT` operations will perform better indefinitely compared to `FILLFACTOR = 100`?
    *   **Answer:** Not necessarily indefinitely. Initially, `FILLFACTOR = 50` will likely lead to fewer page splits immediately after the rebuild, potentially improving `INSERT` performance in the short term. However, it also means the index takes up roughly twice the disk space and requires reading twice as many pages for scans. As inserts continue, the 50% free space will eventually fill up, and page splits will start occurring again. The optimal fill factor balances the cost of page splits against the cost of increased index size and scan I/O over the typical maintenance cycle for that index. A very low fill factor might hurt scan performance more than it helps insert performance in the long run.
10. **[Hard/Tricky]** Does the fill factor setting affect the non-leaf (intermediate) levels of an index B-tree?
    *   **Answer:** Yes, although indirectly. While the `FILLFACTOR` percentage specifically controls the leaf-level pages, SQL Server also reserves *some* free space on the non-leaf (intermediate) index pages during a create/rebuild. The amount of space reserved on non-leaf pages is related to, but not directly controlled by, the leaf-level fill factor setting. This is because splits at the intermediate levels are also possible and need some room. However, the primary impact and control point of the `FILLFACTOR` setting is the leaf level.
