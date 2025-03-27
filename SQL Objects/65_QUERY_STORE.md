# SQL Deep Dive: Query Store

## 1. Introduction: What is Query Store?

**Query Store** is a database-level feature (introduced in SQL Server 2016) that automatically captures a history of **queries, execution plans, and runtime statistics**. It acts like a "flight data recorder" for your database's query performance.

**Why is Query Store Important?**

*   **Performance Troubleshooting Over Time:** Unlike the plan cache (which is volatile), Query Store persists query performance data across server restarts. This allows you to analyze performance trends, compare performance before and after changes (e.g., index changes, SQL Server upgrades), and diagnose issues that occurred in the past.
*   **Identifying Performance Regressions:** Easily identify queries whose performance has degraded due to changes in execution plans (e.g., after statistics updates, schema changes, or parameter sniffing).
*   **Plan Stability (Plan Forcing):** Allows you to **force** SQL Server to use a specific, known-good execution plan for a particular query, overriding the optimizer's choice. This is a powerful way to stabilize performance for problematic queries without using plan guides or hints directly in the code.
*   **Resource Usage Analysis:** Track CPU, duration, logical/physical reads, memory usage, and wait statistics per query and plan over time.
*   **Top Resource Consumers:** Quickly identify the queries consuming the most resources.

## 2. Query Store Configuration and Usage: Analysis of `65_QUERY_STORE.sql`

This script demonstrates enabling, configuring, querying, and managing Query Store.

**Part 1: Fundamentals**

*   Recaps the purpose and benefits of Query Store.

**Part 2: Enabling and Configuring Query Store (`ALTER DATABASE ... SET QUERY_STORE ...`)**

```sql
-- Enable (basic)
ALTER DATABASE HRSystem SET QUERY_STORE = ON;

-- Configure with options
ALTER DATABASE HRSystem SET QUERY_STORE (
    OPERATION_MODE = READ_WRITE, -- Or READ_ONLY
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30), -- Keep data for 30 days
    DATA_FLUSH_INTERVAL_SECONDS = 900, -- Write to disk every 15 mins
    INTERVAL_LENGTH_MINUTES = 60, -- Aggregate stats hourly
    MAX_STORAGE_SIZE_MB = 1000, -- Max disk space (1 GB)
    QUERY_CAPTURE_MODE = ALL, -- Capture ALL queries (vs AUTO/NONE)
    SIZE_BASED_CLEANUP_MODE = AUTO, -- Auto-cleanup if near max size
    MAX_PLANS_PER_QUERY = 200 -- Max plans per query before purging oldest
);

-- Check configuration
SELECT * FROM sys.database_query_store_options;
```

*   **Explanation:** Query Store is enabled per database using `ALTER DATABASE`. Various options control its operation: data retention (`CLEANUP_POLICY`), data flush frequency (`DATA_FLUSH_INTERVAL_SECONDS`), statistics aggregation interval (`INTERVAL_LENGTH_MINUTES`), storage limits (`MAX_STORAGE_SIZE_MB`), which queries are captured (`QUERY_CAPTURE_MODE`), and cleanup behavior. Careful configuration is needed based on workload and monitoring requirements.

**Part 3: Monitoring Query Performance (Query Store Views)**

```sql
-- Overall runtime stats
SELECT * FROM sys.dm_db_query_store_runtime_stats;

-- Top resource consumers (joining views)
SELECT q.query_id, qt.query_sql_text, rs.count_executions, rs.avg_duration, ...
FROM sys.query_store_query q
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
ORDER BY rs.avg_cpu_time DESC;

-- Performance over time for a specific query
SELECT q.query_id, ..., rsi.start_time, rsi.end_time, rs.avg_duration, ...
FROM sys.query_store_query q JOIN ... JOIN sys.query_store_runtime_stats rs ON ...
JOIN sys.query_store_runtime_stats_interval rsi ON rs.runtime_stats_interval_id = rsi.runtime_stats_interval_id
WHERE q.query_id = @SpecificQueryID ORDER BY rsi.start_time;

-- Compare performance across different plans for the same query
SELECT p.plan_id, p.query_id, AVG(rs.avg_duration) AS avg_duration, ...
FROM sys.query_store_plan p JOIN sys.query_store_runtime_stats rs ON p.plan_id = rs.plan_id
WHERE p.query_id = @SpecificQueryID GROUP BY p.plan_id, p.query_id ORDER BY avg_duration;
```

*   **Explanation:** Demonstrates querying the core Query Store catalog views:
    *   `sys.query_store_query_text`: Stores the text of queries.
    *   `sys.query_store_query`: Represents normalized queries (ignoring literal values).
    *   `sys.query_store_plan`: Stores execution plans associated with queries.
    *   `sys.query_store_runtime_stats`: Stores aggregated runtime statistics (duration, CPU, reads, etc.) per plan per time interval.
    *   `sys.query_store_runtime_stats_interval`: Defines the time intervals for statistics aggregation.
*   These views are joined to analyze performance trends, identify top consumers, and compare different plans for the same query.

**Part 4: Identifying Performance Regressions**

```sql
-- Find queries with multiple plans and high variance
SELECT q.query_id, ..., COUNT(DISTINCT p.plan_id) AS number_of_plans, MAX(rs.avg_duration) - MIN(rs.avg_duration) AS duration_variance
FROM sys.query_store_query q JOIN ... JOIN sys.query_store_plan p ON ... JOIN sys.query_store_runtime_stats rs ON ...
GROUP BY q.query_id, ... HAVING COUNT(DISTINCT p.plan_id) > 1 ORDER BY duration_variance DESC;

-- Find queries with recent degradation (comparing recent vs historical avg duration)
SELECT q.query_id, ..., rs_recent.avg_duration, rs_history.avg_duration, ...
FROM sys.query_store_query q JOIN ... JOIN sys.query_store_plan p ON ...
JOIN (SELECT plan_id, AVG(avg_duration) AS avg_duration FROM ... WHERE rsi.start_time >= DATEADD(day, -1, GETUTCDATE()) ...) AS rs_recent ON ...
JOIN (SELECT plan_id, AVG(avg_duration) AS avg_duration FROM ... WHERE rsi.start_time >= DATEADD(month, -1, GETUTCDATE()) AND rsi.start_time < DATEADD(day, -1, GETUTCDATE()) ...) AS rs_history ON ...
WHERE rs_recent.avg_duration > rs_history.avg_duration * 1.5; -- e.g., 50% slower
```

*   **Explanation:** Shows queries designed to specifically identify regressions:
    *   Finding queries that have generated multiple execution plans and exhibit significant variation in performance between those plans.
    *   Comparing recent average performance (e.g., last day) with historical average performance (e.g., last month excluding last day) to find queries that have become significantly slower recently.

**Part 5: Forcing Execution Plans (`sp_query_store_force_plan`, `sp_query_store_unforce_plan`)**

```sql
-- Force a specific plan
EXEC sp_query_store_force_plan @query_id = 42, @plan_id = 142;

-- Unforce a plan
EXEC sp_query_store_unforce_plan @query_id = 42, @plan_id = 142;

-- View forced plans
SELECT q.query_id, ..., p.plan_id, p.is_forced_plan, p.force_failure_count, ...
FROM sys.query_store_query q JOIN ... JOIN sys.query_store_plan p ON ...
WHERE p.is_forced_plan = 1;

-- Example: Find best plan and force it
DECLARE @query_id INT = 42; DECLARE @best_plan_id INT;
SELECT TOP 1 @best_plan_id = p.plan_id FROM sys.query_store_plan p JOIN ... WHERE p.query_id = @query_id ORDER BY AVG(rs.avg_duration) ASC;
IF @best_plan_id IS NOT NULL EXEC sp_query_store_force_plan @query_id = @query_id, @plan_id = @best_plan_id;
```

*   **Explanation:** Demonstrates using system stored procedures to manage plan forcing.
    *   `sp_query_store_force_plan`: Instructs SQL Server to always use the specified `plan_id` for the given `query_id`, overriding the optimizer's choice.
    *   `sp_query_store_unforce_plan`: Removes the forcing instruction, allowing the optimizer to choose plans normally again.
    *   Querying `sys.query_store_plan` (`is_forced_plan` column) shows which plans are currently forced.

**Part 6: Query Store Reports and Maintenance**

*   **Catalog Views:** Lists the core Query Store views again (`sys.query_store_query_text`, `_query`, `_plan`, `_runtime_stats`, `_runtime_stats_interval`, `_wait_stats`).
*   **Maintenance Procedures:**
    *   `sp_query_store_reset_exec_stats`: Clears runtime statistics.
    *   `sp_query_store_remove_query`: Removes a specific query (and its plans/stats).
    *   `sp_query_store_remove_plan`: Removes a specific plan.
    *   `sp_query_store_flush_db`: Manually forces in-memory Query Store data to be written to disk.
*   **Custom Reports:** Provides examples of more complex queries built on the catalog views to find top consumers or queries with high variance.
*   **SSMS UI:** Query Store also has a rich graphical interface within SQL Server Management Studio (SSMS) under the database node, providing built-in reports for top consumers, regressed queries, plan comparison, and plan forcing capabilities.

## 3. Targeted Interview Questions (Based on `65_QUERY_STORE.sql`)

**Question 1:** What is the primary benefit of Query Store compared to analyzing the plan cache using DMVs like `sys.dm_exec_query_stats`?

**Solution 1:** The primary benefit is **persistence**. Query Store data (query text, plans, runtime statistics) is stored persistently within the user database itself and survives server restarts. The plan cache (`sys.dm_exec_query_stats`, etc.) is stored in memory and is volatile; its contents are cleared upon server restarts, memory pressure, or certain configuration changes. Query Store allows for historical performance analysis and tracking regressions over time, which is not possible with the plan cache alone.

**Question 2:** What does it mean to "force" an execution plan using Query Store, and why might you do this?

**Solution 2:** Forcing an execution plan means instructing SQL Server, via `sp_query_store_force_plan`, to always use a specific, previously captured plan (`plan_id`) whenever it executes a particular query (`query_id`), regardless of current statistics or parameter values. You might do this to resolve a performance regression where the optimizer has started choosing a less efficient plan, allowing you to lock in a known-good plan while investigating the root cause, or to stabilize performance for a critical query sensitive to parameter sniffing.

## 4. Tricky Interview Questions (Easy to Hard)

1.  **[Easy]** Is Query Store enabled by default for new databases in recent SQL Server versions?
    *   **Answer:** Yes, starting with SQL Server 2022 (and often enabled by default in Azure SQL Database), Query Store is typically enabled by default for new databases. In earlier versions (SQL 2016-2019), it needed to be enabled manually (`ALTER DATABASE ... SET QUERY_STORE = ON;`).
2.  **[Easy]** Where is Query Store data physically stored?
    *   **Answer:** Within the user database itself, primarily in the `PRIMARY` filegroup.
3.  **[Medium]** What does the `QUERY_CAPTURE_MODE` setting control in Query Store configuration? What are the options?
    *   **Answer:** It controls which queries are captured by Query Store. Options are:
        *   `ALL`: Captures all queries executed.
        *   `AUTO`: Captures significant queries based on execution count and resource consumption thresholds (ignores infrequent or low-impact queries).
        *   `NONE`: Disables capturing *new* queries (but continues collecting stats for already captured ones if `OPERATION_MODE` is `READ_WRITE`).
4.  **[Medium]** What happens if Query Store reaches its configured `MAX_STORAGE_SIZE_MB` limit?
    *   **Answer:** Query Store automatically transitions its `OPERATION_MODE` to `READ_ONLY`. It stops capturing new queries and statistics but retains the existing data for analysis. If `SIZE_BASED_CLEANUP_MODE` is set to `AUTO` (default), it will also automatically start purging the oldest data to try and free up space before transitioning to `READ_ONLY`.
5.  **[Medium]** Can Query Store capture wait statistics associated with query executions?
    *   **Answer:** Yes, starting with SQL Server 2017, Query Store can optionally capture wait statistics aggregated per query plan over time intervals (stored in `sys.query_store_wait_stats`). This needs to be enabled via `ALTER DATABASE ... SET QUERY_STORE (WAIT_STATS_CAPTURE_MODE = ON);`.
6.  **[Medium]** Does forcing a plan using `sp_query_store_force_plan` guarantee that the plan will always be used successfully?
    *   **Answer:** No. While SQL Server will *attempt* to use the forced plan, the forcing can fail if the plan becomes invalid due to subsequent schema changes (e.g., dropping an index the plan relies on) or other factors. You can monitor `sys.query_store_plan` for `force_failure_count` and `last_force_failure_reason_desc`.
7.  **[Hard]** How does Query Store handle ad-hoc queries versus parameterized queries or stored procedures in terms of identifying unique queries?
    *   **Answer:** Query Store groups queries based on their normalized text, identified by `query_hash` and stored as a single entry in `sys.query_store_query` (linked to `sys.query_store_query_text`).
        *   **Stored Procedures/Parameterized Queries:** Typically result in a single `query_id` because the structure is the same, even with different parameter values. Query Store tracks different plans generated due to parameter sniffing under this single `query_id`.
        *   **Ad-hoc Queries:** If ad-hoc queries are not parameterized (i.e., literal values are embedded directly in the query text), each query with different literal values might be treated as a distinct query (`query_id`), potentially "polluting" Query Store with many similar entries. Enabling "Optimize for Ad hoc Workloads" server setting or encouraging application-level parameterization helps mitigate this.
8.  **[Hard]** Can Query Store data be backed up and restored independently of the database?
    *   **Answer:** No. Query Store data resides within the user database's internal tables (in the `PRIMARY` filegroup). It is backed up and restored *along with the database* as part of standard database backups (`FULL`, `DIFFERENTIAL`, `LOG`). There is no separate backup mechanism specifically for Query Store data.
9.  **[Hard]** What is the difference between `INTERVAL_LENGTH_MINUTES` and `DATA_FLUSH_INTERVAL_SECONDS` in Query Store configuration?
    *   **Answer:**
        *   `INTERVAL_LENGTH_MINUTES`: Defines the time window over which runtime execution statistics are **aggregated** before being stored in `sys.query_store_runtime_stats`. For example, a value of 60 means stats are aggregated hourly.
        *   `DATA_FLUSH_INTERVAL_SECONDS`: Defines how frequently the Query Store data captured **in memory** is asynchronously **written to disk** for persistence. This is independent of the aggregation interval. A shorter flush interval reduces potential data loss on crash but increases I/O overhead.
10. **[Hard/Tricky]** If you force a plan using Query Store, and then a new, potentially better index is created that could benefit the query, will SQL Server automatically switch to using the new index if the plan remains forced?
    *   **Answer:** No. If a plan is forced via Query Store, SQL Server will continue to use that specific forced plan, even if changes like new indexes or updated statistics might allow the optimizer to generate a significantly better plan. The forced plan overrides the optimizer's normal decision-making process. To take advantage of the new index, you would need to unforce the old plan (`sp_query_store_unforce_plan`) and allow the optimizer to compile a new plan that considers the new index.
