# SQL Deep Dive: Statistics

## 1. Introduction: What are Statistics?

**Statistics** in SQL Server are database objects that contain statistical information about the **distribution of values** in one or more columns of a table or indexed view. They are arguably the **most critical input** for the SQL Server Query Optimizer.

**Why are Statistics Important?**

*   **Cardinality Estimation:** The primary purpose of statistics is to help the Query Optimizer estimate the **cardinality** (number of rows) that will be returned by different parts of a query plan (e.g., how many rows match a `WHERE` clause, how many rows will result from a `JOIN`).
*   **Plan Choice:** Based on these cardinality estimates, the optimizer makes crucial decisions about which execution plan to use, such as:
    *   Which index (if any) to use (seek vs. scan).
    *   Which join algorithm to employ (Nested Loops, Merge, Hash Match).
    *   The optimal order in which to join tables.
    *   How much memory to grant for operations like sorts or hash joins.
*   **Performance:** Accurate statistics lead to accurate cardinality estimates, which enable the optimizer to choose efficient execution plans, resulting in good query performance. Inaccurate or outdated statistics lead to poor estimates and potentially disastrously slow query plans.

**What do Statistics Contain?**

*   **Header:** Metadata about the statistics (name, last update time, rows sampled, etc.).
*   **Density Vector:** Information about the uniqueness of values for column prefixes.
*   **Histogram:** A representation of the data distribution for the *first* column in the statistics object. It divides the range of values into up to 200 steps (buckets) and stores information about the number of rows falling within each step and the distinct values at the step boundaries.

## 2. Statistics Management in Action: Analysis of `66_STATISTICS.sql`

This script covers automatic and manual statistics management, viewing statistics, and troubleshooting.

**Part 1: Fundamentals**

*   Explains what statistics are and why they are crucial for the query optimizer's cost-based decisions.

**Part 2: Automatic Statistics Management**

*   **Auto-Create Statistics (`AUTO_CREATE_STATISTICS ON`):**
    *   **Behavior:** SQL Server automatically creates single-column statistics on columns used in predicates (`WHERE`, `JOIN`, etc.) during query optimization if statistics don't already exist and might be helpful.
    *   **Default:** Enabled (`ON`) by default for most databases.
    *   **Command:** `ALTER DATABASE dbName SET AUTO_CREATE_STATISTICS ON/OFF;`
*   **Auto-Update Statistics (`AUTO_UPDATE_STATISTICS ON`):**
    *   **Behavior:** SQL Server automatically updates statistics when a certain threshold of data modifications (inserts, updates, deletes) has occurred on the table. The threshold is dynamic (lower for larger tables since SQL 2008 R2 SP1, controlled by Trace Flag 2371).
    *   **Default:** Enabled (`ON`) by default.
    *   **Command:** `ALTER DATABASE dbName SET AUTO_UPDATE_STATISTICS ON/OFF;`
*   **Auto-Update Statistics Asynchronously (`AUTO_UPDATE_STATISTICS_ASYNC ON`):**
    *   **Behavior:** When statistics need updating, the query currently running uses the *old* statistics to compile its plan immediately. The statistics update then runs in the background. Subsequent queries will use the newly updated statistics. This avoids making queries wait for statistics updates to complete.
    *   **Default:** Disabled (`OFF`) by default.
    *   **Trade-off:** The first query triggering the async update might run with a suboptimal plan based on stale statistics.
    *   **Command:** `ALTER DATABASE dbName SET AUTO_UPDATE_STATISTICS_ASYNC ON/OFF;`

**Part 3: Manually Managing Statistics**

*   **Create Statistics (`CREATE STATISTICS`)**
    ```sql
    CREATE STATISTICS Stats_Name ON TableName(Column1 [, Column2...])
    [WHERE FilterPredicate] -- Filtered Statistics
    [WITH Options]; -- e.g., FULLSCAN, SAMPLE, NORECOMPUTE
    ```
    *   **Explanation:** Manually creates statistics objects. Useful for:
        *   Multi-column statistics (when columns are often queried together).
        *   Statistics on columns not automatically created (e.g., not used directly in predicates).
        *   Filtered statistics (on a subset of rows defined by a `WHERE` clause, useful for skewed data).
*   **Update Statistics (`UPDATE STATISTICS`)**
    ```sql
    UPDATE STATISTICS TableName | ViewName [ StatisticsName | IndexName ]
    [WITH Options]; -- e.g., FULLSCAN, SAMPLE PERCENT/ROWS, RESAMPLE, ALL, COLUMNS, INDEX
    ```
    *   **Explanation:** Manually forces an update of statistics, rebuilding the histogram and density information based on current data.
    *   **Options:**
        *   `FULLSCAN`: Reads all rows in the table. Most accurate but most resource-intensive.
        *   `SAMPLE n PERCENT` / `SAMPLE n ROWS`: Uses a statistical sample. Faster but less accurate than `FULLSCAN`.
        *   `RESAMPLE`: Updates using the most recent sample rate.
        *   `ALL` | `COLUMNS` | `INDEX`: Specifies whether to update all stats, only column stats, or only index stats.
*   **Drop Statistics (`DROP STATISTICS`)**
    ```sql
    DROP STATISTICS TableName.StatisticsName;
    ```
    *   **Explanation:** Removes a manually created or automatically created statistics object. Generally only done if the statistics are found to be unused or harmful.

**Part 4: Viewing Statistics Information**

*   **List Statistics (`sys.stats`, `sys.stats_columns`)**
    ```sql
    SELECT s.name, ..., STATS_DATE(s.object_id, s.stats_id) AS last_updated
    FROM sys.stats s JOIN sys.stats_columns sc ON ... WHERE s.object_id = OBJECT_ID(...);
    ```
    *   **Explanation:** Queries system views to list statistics objects associated with a table, the columns they cover, and when they were last updated.
*   **View Histogram (`DBCC SHOW_STATISTICS`)**
    ```sql
    DBCC SHOW_STATISTICS ('TableName', 'StatisticsName | IndexName');
    ```
    *   **Explanation:** Displays the detailed statistics information, including the header, density vector, and crucially, the **histogram** (showing value distribution across steps). Essential for deep analysis of data skew and optimizer estimates.
*   **View Statistics Properties (DMV - `sys.dm_db_stats_properties`)**
    ```sql
    SELECT OBJECT_NAME(s.object_id), s.name, sp.last_updated, sp.rows, sp.rows_sampled, sp.modification_counter, ...
    FROM sys.stats s CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp WHERE ...;
    ```
    *   **Explanation:** A DMV (SQL 2008 R2 SP2+) providing properties like last update time, rows in table at time of update, rows sampled, and importantly, `modification_counter` (tracking changes since the last update). Useful for identifying stale statistics.

**Part 5: Statistics and Query Performance**

*   **Outdated Statistics:** If data changes significantly but statistics aren't updated, the optimizer's cardinality estimates will be wrong, likely leading to poor plan choices (e.g., choosing a scan when a seek would be better, or vice-versa). Manually updating (`UPDATE STATISTICS`) can resolve this.
*   **Missing Statistics:** If `AUTO_CREATE_STATISTICS` is off or doesn't cover a specific column combination used in predicates, the optimizer lacks distribution information, leading to default guesses and potentially bad plans. Manually creating statistics (`CREATE STATISTICS`) can help.

**Part 6: Troubleshooting Statistics Issues**

*   **Identifying Outdated Statistics:** Use `sys.dm_db_stats_properties` to check `modification_counter` and `last_updated`. High modification counts relative to total rows indicate staleness.
*   **Parameter Sniffing:** While not solely a statistics issue, outdated statistics can exacerbate parameter sniffing problems. Updating statistics is often a first step. Other solutions include query hints (`OPTIMIZE FOR`, `RECOMPILE`) or Query Store plan forcing.
*   **Ascending Key Problem:** For columns where new data values are always increasing (like `IDENTITY` or date/time columns), the histogram becomes quickly outdated as new values fall outside the recorded range. Solutions:
    *   Regular `UPDATE STATISTICS WITH FULLSCAN`.
    *   Trace Flag 2389/2390 (tells optimizer to make better guesses for values outside the histogram range).
    *   Incremental Statistics (SQL 2014+ for partitioned tables).

**Part 7: Statistics Maintenance Strategies**

*   **Regular Updates:** Implement scheduled jobs (e.g., SQL Agent) to update statistics regularly, especially for critical or volatile tables.
*   **`FULLSCAN` vs. Sampling:** Use `FULLSCAN` for critical/smaller tables where accuracy is paramount. Use sampling (`SAMPLE n PERCENT`) for very large tables where `FULLSCAN` takes too long, balancing accuracy and resource usage. Default auto-update uses sampling.
*   **After Bulk Operations:** Manually update statistics after large data loads or deletes, as auto-update might not trigger immediately or sufficiently.
*   **Index Rebuilds:** `ALTER INDEX ... REBUILD` automatically updates the corresponding index statistics with `FULLSCAN` equivalent accuracy. `ALTER INDEX ... REORGANIZE` does *not* update statistics.

**Part 8: Real-World Scenarios**

*   **Slow Query Investigation:** Check execution plan for bad estimates, then use `DBCC SHOW_STATISTICS` and `sys.dm_db_stats_properties` to check the relevant statistics' age and histogram. Update if necessary.
*   **Skewed Data:** If data is unevenly distributed (e.g., 90% of orders have `Status = 'Completed'`), standard histograms might not accurately represent the minority values. Consider creating **filtered statistics** on the less common values (`WHERE Status <> 'Completed'`) to give the optimizer better information for queries targeting those values.
*   **Temporary Tables:** Statistics are generally *not* automatically created or updated on temporary tables (`#temp`). If complex queries involving joins or filtering are run against large temp tables within a procedure, manually create statistics on the temp table after populating it to potentially improve performance.

**Part 9: Best Practices**

*   Keep `AUTO_CREATE` and `AUTO_UPDATE` ON (default).
*   Consider `AUTO_UPDATE_ASYNC ON` for high-throughput OLTP.
*   Update stats after large data modifications.
*   Create multi-column stats where needed (correlated columns often queried together).
*   Use filtered stats for known data skew.
*   Monitor stats age/modifications.
*   Use `FULLSCAN` where feasible, sample large tables appropriately.
*   Be aware of ascending key issues.
*   Have a regular maintenance plan.

## 3. Targeted Interview Questions (Based on `66_STATISTICS.sql`)

**Question 1:** What is the primary purpose of statistics in SQL Server query optimization?

**Solution 1:** The primary purpose is to provide the Query Optimizer with information about the **distribution of data values** within table columns. This allows the optimizer to make accurate **cardinality estimates** (estimating the number of rows affected by different operations), which are crucial for choosing the most efficient execution plan (e.g., selecting appropriate indexes and join algorithms).

**Question 2:** What is the difference between `UPDATE STATISTICS TableName WITH FULLSCAN` and the default automatic statistics update?

**Solution 2:**

*   `UPDATE STATISTICS ... WITH FULLSCAN`: Reads **all rows** in the table to build the statistics histogram and density information. This provides the most accurate statistics but can be resource-intensive (I/O, CPU, time) on very large tables.
*   **Automatic Statistics Update:** Triggered when a certain threshold of data modifications has occurred. By default, it uses **sampling** (reading only a subset of rows) to update the statistics. This is faster and less resource-intensive than `FULLSCAN` but may result in less accurate statistics, especially if the data distribution is skewed or has changed significantly.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Are statistics automatically created on columns included in an index key?
    *   **Answer:** Yes. When an index is created (or rebuilt), SQL Server automatically creates statistics on the key column(s) of that index.
2.  **[Easy]** What command displays the histogram for a statistics object?
    *   **Answer:** `DBCC SHOW_STATISTICS ('TableName', 'StatisticsName | IndexName')`.
3.  **[Medium]** If `AUTO_UPDATE_STATISTICS` is ON, does SQL Server update statistics immediately after every single row modification?
    *   **Answer:** No. Auto-update is triggered only after a certain **threshold** of modifications has occurred (roughly related to table size, e.g., 20% + 500 rows, but dynamic in newer versions).
4.  **[Medium]** Can you create statistics on more than one column? What is this called?
    *   **Answer:** Yes. This is called **multi-column statistics**. The order of columns specified in `CREATE STATISTICS` matters, as the histogram is only built on the first column.
5.  **[Medium]** Does `ALTER INDEX ... REORGANIZE` update statistics?
    *   **Answer:** No. Only `ALTER INDEX ... REBUILD` updates statistics (with `FULLSCAN` accuracy).
6.  **[Medium]** What information does the `modification_counter` in `sys.dm_db_stats_properties` provide?
    *   **Answer:** It shows the number of rows that have been modified in the leading column of the statistics object since the statistics were last updated. It's a key indicator of statistics staleness.
7.  **[Hard]** What are filtered statistics, and when are they particularly useful?
    *   **Answer:** Filtered statistics are statistics created on a *subset* of rows in a table, defined by a `WHERE` clause in the `CREATE STATISTICS` statement. They are particularly useful when dealing with **highly skewed data distributions**, where a standard histogram based on all rows might not accurately represent the distribution within a specific subset frequently targeted by queries. Creating filtered statistics on that subset provides the optimizer with more accurate cardinality estimates for queries filtering on that subset.
8.  **[Hard]** Explain the "ascending key problem" related to statistics and how it can affect query performance.
    *   **Answer:** The ascending key problem occurs with columns where new data values are consistently outside the range of existing values captured in the statistics histogram (e.g., an `IDENTITY` column or a `DATETIME` column recording insertion time). When statistics are updated, the highest value recorded in the histogram is the highest value *at that time*. Queries filtering for values *higher* than this maximum (i.e., newly inserted data) cannot be accurately estimated by the optimizer using the histogram; it has to guess. These guesses are often inaccurate (typically too low), leading to suboptimal plan choices (e.g., Nested Loops when Hash Match would be better).
9.  **[Hard]** What is the potential drawback of enabling `AUTO_UPDATE_STATISTICS_ASYNC ON`?
    *   **Answer:** The main drawback is that the *first* query (or queries) that trigger the asynchronous update will execute using the *stale* statistics before the background update completes. This means these initial queries might run with a suboptimal execution plan. Subsequent queries will benefit from the updated statistics once the background update finishes.
10. **[Hard/Tricky]** Can manually created statistics (`CREATE STATISTICS`) conflict with automatically created statistics or index statistics? How does the optimizer choose which statistics to use if multiple relevant ones exist?
    *   **Answer:** Yes, you can have multiple statistics objects covering the same column(s) (e.g., auto-created single-column, manual multi-column, index statistics). The query optimizer will generally choose the statistics it deems most useful for estimating the cardinality of a specific predicate based on factors like:
        *   **Column Coverage:** Statistics covering multiple columns in a predicate are often preferred over single-column stats.
        *   **Filtered vs. Full:** Filtered statistics matching the query's `WHERE` clause might be preferred over full statistics.
        *   **Recency/Accuracy:** More recently updated statistics might be favored (though the choice is primarily based on predicate matching).
        *   **Index Statistics:** Statistics associated with an index being considered for the plan are often used.
    *   Having redundant or conflicting statistics doesn't usually cause errors but can add maintenance overhead (more stats to update) and potentially confuse the optimizer in rare cases. It's generally good practice to review and potentially drop redundant manually created statistics if auto-created or index statistics are sufficient.
